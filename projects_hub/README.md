# Mes Projets — tous tes projets dans une appli Android

Application Android (Flutter) qui réunit tous tes projets (HTML/JS, sites,
applis) sur un seul écran d'accueil, et les fait **fonctionner directement
dans l'appli**.

## Sources possibles

| Source | Comment ça marche |
|---|---|
| **GitHub (branche)** | L'appli télécharge le ZIP de la branche, le garde sur le téléphone (marche hors-ligne) et le sert via un petit serveur web local (`http://127.0.0.1`). À chaque ouverture elle vérifie s'il y a un nouveau commit et se met à jour toute seule. |
| **Dossier du téléphone** | Un dossier HTML déjà sur l'appareil (demande l'autorisation « Accès à tous les fichiers »). Les modifications du dossier sont visibles tout de suite. |
| **Importer un ZIP** | Le ZIP est copié dans l'appli, fonctionne hors-ligne. |
| **Site / serveur distant** | N'importe quelle URL : GitHub Pages, un site en ligne, ou ton PC sur le même Wi-Fi (ex. `http://192.168.1.20:8000` avec `python -m http.server`, comme `server.bat` du Burger Quiz). |
| **Application Android** | Lance une appli installée par son identifiant (ex. RusPath `com.ruspath.russian_learning_app`) et propose de télécharger l'APK si elle n'est pas installée. |

Au premier lancement, quatre projets sont déjà configurés :
**Burger Quiz** (`JK-ASFC/SW`, en paysage et plein écran),
**RusPath** (appli Android, APK de la release `ruspath-latest`) et
**Portfolio** (`JK-ASFC/portfolio`) et **Fondu musique**
(`JK-ASFC/fondu-musique`, branche `main`, en portrait — crée ce dépôt et
dépose-y les fichiers du projet avec un `index.html` à la racine pour qu'il
fonctionne). Les projets par défaut ajoutés dans une nouvelle version
apparaissent aussi sur une appli déjà installée ; un projet par défaut que
tu as supprimé ne revient pas.

### Pourquoi un serveur local ?

Servir les fichiers en `http://` plutôt qu'en `file://` fait marcher les
projets exactement comme avec `python -m http.server` : `fetch()`, modules
JS, `localStorage`, IndexedDB (utilisé par le Burger Quiz pour les slides et
médias), vidéos avec avance rapide (requêtes Range)… Chaque projet a son
propre port fixe, donc ses données sauvegardées sont conservées d'une
ouverture à l'autre et ne se mélangent pas avec celles des autres projets.

## Ajouter un projet GitHub

`Ajouter` → `Depuis GitHub` : l'appli liste les dépôts du compte
(`JK-ASFC` par défaut), puis les branches, puis toutes les pages HTML de la
branche — tu choisis la page d'accueil. Si la branche contient une appli
Flutter/Android, elle est détectée et son APK (release GitHub) proposé.

Tu peux aussi coller un lien, ex. `github.com/JK-ASFC/SW/tree/main`.

**Dépôts privés** : `Personnaliser` → `GitHub` → jeton d'accès
(*Fine-grained token*, permission « Contents : Read-only »). Le jeton n'est
stocké que sur le téléphone et n'est jamais inclus dans l'export.

## Personnalisation

- **Par projet** (appui long → *Personnaliser*) : nom, description, emoji,
  couleur, image de couverture, catégorie, favori, page d'accueil,
  sous-dossier, branche, orientation (auto/portrait/paysage), plein écran.
- **Appli** (menu ⋮ → *Personnaliser l'appli*) : titre de l'accueil, thème
  clair/sombre/auto, couleur principale, fond d'écran, grille (1 à 4
  colonnes) ou liste, style des cartes (dégradé, plein, contour), tri (mon
  ordre, nom, récents, plus utilisés), descriptions/badges visibles,
  mise à jour auto.
- **Réorganiser** par glisser-déposer, **catégories** en filtres, recherche.
- **Sauvegarde** : export/import de toute la configuration via le
  presse-papiers.

Dans un projet ouvert : retour = page précédente, menu pour recharger,
revenir à l'accueil du projet, passer en plein écran ou fermer. Les
`alert()/confirm()/prompt()`, l'envoi de fichiers (`<input type=file>`) et
la lecture automatique des sons/vidéos sont gérés.

## Installer l'APK

Le workflow `.github/workflows/build-projects-hub-apk.yml` compile l'APK à
chaque push sur `projects_hub/` :
- artefact `mes-projets-apk` du run GitHub Actions ;
- release GitHub **`mes-projets-latest`** → `mes-projets.apk` (toujours le
  dernier commit).

### Mises à jour sans perdre tes données (recommandé)

Sans clé de signature fixe, chaque APK compilé par GitHub est signé avec
une clé différente : Android refuse alors de l'installer par-dessus
l'ancien (il faut désinstaller, ce qui efface la configuration — exporte-la
avant). Pour éviter ça, crée une clé une fois :

```bash
keytool -genkey -v -keystore hub.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hub
base64 -w0 hub.jks   # copie le résultat
```

puis dans GitHub → *Settings* → *Secrets and variables* → *Actions*, ajoute
`HUB_KEYSTORE_BASE64` (le base64), `HUB_KEYSTORE_PASSWORD`, `HUB_KEY_ALIAS`
(`hub`) et éventuellement `HUB_KEY_PASSWORD`. Garde `hub.jks` en lieu sûr,
ne le commite pas.

## Développement

```bash
cd projects_hub
flutter pub get
flutter analyze
flutter test
flutter run            # téléphone branché en USB
```

Structure :

```
lib/
  main.dart                     thème + démarrage
  models/                       Project, AppSettings
  state/hub_controller.dart     projets, réglages, téléchargements, sauvegarde
  state/presets.dart            projets d'origine
  services/github_service.dart  API GitHub (dépôts, branches, pages, APK, ZIP)
  services/project_files.dart   téléchargement/extraction, dossiers servis
  services/local_server.dart    serveur HTTP local (Range, types MIME)
  services/launcher.dart        ouverture d'un projet selon sa source
  services/native_bridge.dart   lancer une appli, ouvrir un lien, accès fichiers
  screens/                      accueil, lecteur web, GitHub, édition, réglages
android/app/src/main/kotlin/…/MainActivity.kt   pont natif (MethodChannel)
```
