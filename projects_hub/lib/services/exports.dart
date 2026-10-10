import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Saves a small text file (e.g. a playlist exported by a built-in app) where
/// the user can find it: Téléchargements/Boom Player on Android.
Future<String> saveExport(String name, String content) async {
  var safe = p.basename(name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (safe.isEmpty) safe = 'export';
  if (!safe.toLowerCase().endsWith('.json')) safe = '$safe.json';
  if (content.length > 5 * 1024 * 1024) throw const FileSystemException('Fichier trop gros');
  final Directory dir;
  if (Platform.isAndroid) {
    dir = Directory('/storage/emulated/0/Download/Boom Player');
  } else {
    dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'exports'));
  }
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, safe));
  await file.writeAsString(content);
  return file.path;
}
