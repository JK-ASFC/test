import 'package:flutter/material.dart';

enum HubLayout { grid, list }

enum CardStyle { gradient, filled, outlined }

enum SortMode { custom, name, recent, mostUsed }

extension SortModeLabel on SortMode {
  String get label => switch (this) {
        SortMode.custom => 'Mon ordre',
        SortMode.name => 'Nom',
        SortMode.recent => 'Récemment ouverts',
        SortMode.mostUsed => 'Les plus utilisés',
      };
}

extension CardStyleLabel on CardStyle {
  String get label => switch (this) {
        CardStyle.gradient => 'Dégradé',
        CardStyle.filled => 'Couleur pleine',
        CardStyle.outlined => 'Contour',
      };
}

class AppSettings {
  AppSettings({
    this.hubTitle = 'Mes Projets',
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFFFF7A00,
    this.layout = HubLayout.grid,
    this.gridColumns = 2,
    this.cardStyle = CardStyle.gradient,
    this.sortMode = SortMode.custom,
    this.showDescriptions = true,
    this.showSourceBadges = true,
    this.autoUpdate = true,
    this.githubUser = 'JK-ASFC',
    this.githubToken = '',
    this.backgroundImage,
  });

  String hubTitle;
  ThemeMode themeMode;
  int seedColor;
  HubLayout layout;
  int gridColumns;
  CardStyle cardStyle;
  SortMode sortMode;
  bool showDescriptions;
  bool showSourceBadges;

  /// Download a newer commit of a GitHub project automatically when it's opened.
  bool autoUpdate;

  String githubUser;

  /// Optional personal access token: needed for private repositories and
  /// raises GitHub's API rate limit from 60 to 5000 requests/hour.
  String githubToken;

  /// Optional wallpaper behind the project grid.
  String? backgroundImage;

  Map<String, dynamic> toJson({bool includeSecrets = true}) => {
        'hubTitle': hubTitle,
        'themeMode': themeMode.name,
        'seedColor': seedColor,
        'layout': layout.name,
        'gridColumns': gridColumns,
        'cardStyle': cardStyle.name,
        'sortMode': sortMode.name,
        'showDescriptions': showDescriptions,
        'showSourceBadges': showSourceBadges,
        'autoUpdate': autoUpdate,
        'githubUser': githubUser,
        if (includeSecrets) 'githubToken': githubToken,
        'backgroundImage': backgroundImage,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        hubTitle: j['hubTitle'] as String? ?? 'Mes Projets',
        themeMode:
            ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system,
        seedColor: j['seedColor'] as int? ?? 0xFFFF7A00,
        layout: HubLayout.values.asNameMap()[j['layout']] ?? HubLayout.grid,
        gridColumns: (j['gridColumns'] as int? ?? 2).clamp(1, 4),
        cardStyle:
            CardStyle.values.asNameMap()[j['cardStyle']] ?? CardStyle.gradient,
        sortMode: SortMode.values.asNameMap()[j['sortMode']] ?? SortMode.custom,
        showDescriptions: j['showDescriptions'] as bool? ?? true,
        showSourceBadges: j['showSourceBadges'] as bool? ?? true,
        autoUpdate: j['autoUpdate'] as bool? ?? true,
        githubUser: j['githubUser'] as String? ?? 'JK-ASFC',
        githubToken: j['githubToken'] as String? ?? '',
        backgroundImage: j['backgroundImage'] as String?,
      );
}
