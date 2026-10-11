import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projects_hub/models/project.dart';
import 'package:projects_hub/screens/home_screen.dart';
import 'package:projects_hub/services/github_service.dart';
import 'package:projects_hub/services/local_server.dart';
import 'package:projects_hub/services/music_library.dart';
import 'package:projects_hub/services/project_files.dart';
import 'package:projects_hub/state/hub_controller.dart';
import 'package:projects_hub/state/presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('hub_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('LocalServer', () {
    test('resolves files, directories and blocks traversal', () {
      File('${tmp.path}/index.html').writeAsStringSync('<h1>hi</h1>');
      Directory('${tmp.path}/sub').createSync();
      File('${tmp.path}/sub/index.html').writeAsStringSync('sub');
      File('${tmp.path}/sub/a b.css').writeAsStringSync('x');

      expect(LocalServer.resolve(tmp.path, '/')?.path, endsWith('index.html'));
      expect(LocalServer.resolve(tmp.path, '/sub/')?.readAsStringSync(), 'sub');
      expect(LocalServer.resolve(tmp.path, '/sub/a%20b.css'), isNotNull);
      expect(LocalServer.resolve(tmp.path, '/../etc/passwd'), isNull);
      expect(LocalServer.resolve(tmp.path, '/%2e%2e/%2e%2e/etc/passwd'), isNull);
      expect(LocalServer.resolve(tmp.path, '/missing.js'), isNull);
    });

    test('parses Range headers', () {
      expect(LocalServer.parseRange('bytes=0-99', 1000), (0, 99));
      expect(LocalServer.parseRange('bytes=500-', 1000), (500, 999));
      expect(LocalServer.parseRange('bytes=-100', 1000), (900, 999));
      expect(LocalServer.parseRange('bytes=900-5000', 1000), (900, 999));
      expect(LocalServer.parseRange('bytes=2000-', 1000), isNull);
      expect(LocalServer.parseRange(null, 1000), isNull);
    });

    test('ports are stable per project and in range', () {
      final a = LocalServer.portFor('preset-burgerquiz');
      expect(a, LocalServer.portFor('preset-burgerquiz'));
      expect(a, inInclusiveRange(20000, 39999));
      expect(a, isNot(LocalServer.portFor('preset-portfolio')));
    });

    test('serves content types and partial content over HTTP', () async {
      File('${tmp.path}/index.html').writeAsStringSync('<p>Burger</p>');
      File('${tmp.path}/video.mp4').writeAsBytesSync(List.generate(1000, (i) => i % 256));
      // flutter_test replaces HttpClient with a fake returning 400; this
      // test needs real loopback sockets.
      final saved = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = saved);
      final server = await LocalServer.start(tmp.path, 0);
      final client = HttpClient();
      try {
        var req = await client.getUrl(Uri.parse('${server.origin}/'));
        var res = await req.close();
        expect(res.statusCode, 200);
        expect(res.headers.contentType?.mimeType, 'text/html');
        expect(await res.transform(utf8.decoder).join(), '<p>Burger</p>');

        req = await client.getUrl(Uri.parse('${server.origin}/video.mp4'));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
        res = await req.close();
        expect(res.statusCode, 206);
        expect(res.headers.value(HttpHeaders.contentRangeHeader), 'bytes 10-19/1000');
        final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
        expect(bytes, List.generate(10, (i) => 10 + i));

        req = await client.getUrl(Uri.parse('${server.origin}/nope.js'));
        res = await req.close();
        expect(res.statusCode, 404);
        await res.drain<void>();
      } finally {
        client.close(force: true);
        await LocalServer.stopAll();
      }
    });
  });

  group('GithubService helpers', () {
    test('scanPaths finds pages (index first) and Flutter apps', () {
      final scan = GithubService.scanPaths([
        'admin.html',
        'index.html',
        'docs/guide.html',
        'russian_learning_app/pubspec.yaml',
        'russian_learning_app/android/app/build.gradle.kts',
        'tool/pubspec.yaml',
        'node_modules/x/index.html',
      ]);
      expect(scan.htmlFiles, ['index.html', 'admin.html', 'docs/guide.html']);
      expect(scan.flutterApps, ['russian_learning_app']);
    });

    test('parseRepoUrl understands links', () {
      final a = GithubService.parseRepoUrl('https://github.com/JK-ASFC/SW')!;
      expect((a.owner, a.repo, a.branch, a.subdir), ('JK-ASFC', 'SW', null, ''));
      final b = GithubService.parseRepoUrl('github.com/JK-ASFC/test/tree/dev/site/www')!;
      expect((b.owner, b.repo, b.branch, b.subdir), ('JK-ASFC', 'test', 'dev', 'site/www'));
      expect(GithubService.parseRepoUrl('JK-ASFC/portfolio.git')!.repo, 'portfolio');
      expect(GithubService.parseRepoUrl('nope'), isNull);
    });

    test('parseApplicationId reads Gradle files', () {
      expect(GithubService.parseApplicationId('applicationId = "com.ruspath.russian_learning_app"'),
          'com.ruspath.russian_learning_app');
      expect(GithubService.parseApplicationId("applicationId 'com.a.b'"), 'com.a.b');
    });
  });

  group('ProjectFiles', () {
    test('installZip strips the single top-level folder and replaces content', () async {
      final files = ProjectFiles(Directory('${tmp.path}/projects')..createSync());
      final archive = Archive()
        ..addFile(ArchiveFile.string('SW-main/index.html', '<h1>v1</h1>'))
        ..addFile(ArchiveFile.string('SW-main/img/logo.txt', 'logo'));
      final zip = File('${tmp.path}/a.zip')..writeAsBytesSync(ZipEncoder().encode(archive));

      await files.installZip('p1', zip);
      final root = files.contentDir('p1').path;
      expect(File('$root/index.html').readAsStringSync(), '<h1>v1</h1>');
      expect(File('$root/img/logo.txt').existsSync(), isTrue);
      expect(ProjectFiles.listHtml(root), ['index.html']);

      final v2 = Archive()..addFile(ArchiveFile.string('SW-main/index.html', '<h1>v2</h1>'));
      zip.writeAsBytesSync(ZipEncoder().encode(v2));
      await files.installZip('p1', zip);
      expect(File('$root/index.html').readAsStringSync(), '<h1>v2</h1>');
      expect(File('$root/img/logo.txt').existsSync(), isFalse);

      final p = Project(id: 'p1', name: 'x', type: SourceType.github);
      expect(files.serveRoot(p), root);
      p.subdir = 'missing';
      expect(files.serveRoot(p), isNull);
    });
  });

  test('Project JSON round trip', () {
    for (final p in defaultProjects()) {
      final back = Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), p.toJson());
    }
  });

  test('presets added by an update reach existing installs once', () async {
    final firstThree = defaultProjects().where((p) => p.id != 'preset-fondu-musique');
    SharedPreferences.setMockInitialValues({
      'projects_v1': jsonEncode(firstThree.map((p) => p.toJson()).toList()),
    });
    var prefs = await SharedPreferences.getInstance();
    var hub = HubController(prefs, ProjectFiles(tmp))..restore();
    expect(hub.byId('preset-fondu-musique'), isNotNull);

    // Deleted by the user: must not come back on the next launch.
    await hub.remove(hub.byId('preset-fondu-musique')!);
    hub = HubController(prefs, ProjectFiles(tmp))..restore();
    expect(hub.byId('preset-fondu-musique'), isNull);
    expect(hub.projects.length, 3);
  });

  group('Fondu musique', () {
    void song(String rel, {int size = 50000}) {
      final f = File('${tmp.path}/$rel')..createSync(recursive: true);
      f.writeAsBytesSync(List.filled(size, 1));
    }

    test('MusicLibrary finds songs, skips tiny/system/hidden files', () async {
      song('Music/Rock/a.mp3');
      song('Music/b.FLAC');
      song('Download/c.m4a');
      song('Music/blip.mp3', size: 100);
      song('Notifications/ding.ogg');
      song('Android/data/x/d.mp3');
      song('.hidden/e.mp3');
      song('Music/cover.jpg');
      final lib = MusicLibrary(roots: [tmp.path]);
      final data = await lib.list();
      final names = (data['tracks'] as List).map((t) => (t as Map)['name']).toList();
      expect(names, ['c', 'b', 'a']); // Download < Music < Music/Rock
      expect(lib.allows('${tmp.path}/Music/b.FLAC'), isTrue);
      expect(lib.allows('${tmp.path}/Music/cover.jpg'), isFalse);
      expect(lib.allows('/etc/passwd'), isFalse);
      expect(lib.allows('${tmp.path}/../x.mp3'), isFalse);

      final denied = MusicLibrary(roots: [tmp.path], hasPermission: () async => false);
      expect((await denied.list())['needPermission'], isTrue);
    });

    test('music API is only served when a library is attached', () async {
      song('Music/a.mp3');
      final saved = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = saved);
      final client = HttpClient();
      Future<int> status(String path) async {
        final r = await (await client.getUrl(Uri.parse(path))).close();
        await r.drain<void>();
        return r.statusCode;
      }

      try {
        var server = await LocalServer.start(tmp.path, 0);
        expect(await status('${server.origin}/__hub/music'), 404);
        await LocalServer.stopAll();

        server = await LocalServer.start(tmp.path, 0, music: MusicLibrary(roots: [tmp.path]));
        final r = await (await client.getUrl(Uri.parse('${server.origin}/__hub/music'))).close();
        final json = jsonDecode(await r.transform(utf8.decoder).join()) as Map;
        expect((json['tracks'] as List).single['name'], 'a');
        final file = Uri.encodeComponent('${tmp.path}/Music/a.mp3');
        expect(await status('${server.origin}/__hub/music/file?p=$file'), 200);
        expect(await status('${server.origin}/__hub/music/file?p=%2Fetc%2Fpasswd'), 404);
      } finally {
        client.close(force: true);
        await LocalServer.stopAll();
      }
    });

    test('built-in app is installed from the bundled assets', () async {
      final files = ProjectFiles(Directory('${tmp.path}/projects')..createSync());
      final p = fonduMusique();
      await files.installBuiltin(p);
      final root = files.serveRoot(p)!;
      for (final f in ['index.html', 'app.js', 'style.css']) {
        expect(File('$root/$f').existsSync(), isTrue, reason: f);
      }
    });

    test('v2 GitHub preset is migrated to the built-in app', () async {
      final old = Project.fromJson(fonduMusique().toJson())
        ..type = SourceType.github
        ..builtin = null
        ..owner = 'JK-ASFC'
        ..repo = 'fondu-musique'
        ..description = 'Fondu enchaîné entre musiques — version téléphone.';
      SharedPreferences.setMockInitialValues({
        'projects_v1': jsonEncode([old.toJson()]),
        'seen_presets_v1': defaultProjects().map((d) => d.id).toList(),
      });
      final prefs = await SharedPreferences.getInstance();
      final hub = HubController(prefs, ProjectFiles(tmp))..restore();
      final f = hub.byId('preset-fondu-musique')!;
      expect(f.type, SourceType.builtin);
      expect(f.builtin, 'fondu_musique');
      expect(f.description, fonduMusique().description);
    });
  });

  testWidgets('home shows the preset projects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final hub = HubController(prefs, ProjectFiles(tmp));
    // Load presets without touching the network.
    hub.projects = defaultProjects();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(hub: hub)));
    await tester.pump();
    expect(find.text('Burger Quiz'), findsOneWidget);
    expect(find.text('RusPath — Russe'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);
  });
}
