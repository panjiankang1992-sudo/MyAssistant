import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum AppThemeMode {
  system('system', '跟随系统', '随设备外观自动切换', Icons.settings_suggest_rounded),
  light('light', '浅色', '明亮、清爽，适合白天使用', Icons.light_mode_rounded),
  dark('dark', '深色', '降低亮度，适合夜间和弱光环境', Icons.dark_mode_rounded);

  final String value;
  final String label;
  final String description;
  final IconData icon;

  const AppThemeMode(this.value, this.label, this.description, this.icon);

  static AppThemeMode fromValue(String? value) {
    return AppThemeMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

enum AppThemeDensity {
  comfortable('comfortable', '舒适', '留白更多，适合触摸操作', Icons.space_bar_rounded),
  compact('compact', '紧凑', '信息更密集，适合桌面浏览', Icons.view_agenda_rounded);

  final String value;
  final String label;
  final String description;
  final IconData icon;

  const AppThemeDensity(this.value, this.label, this.description, this.icon);

  static AppThemeDensity fromValue(String? value) {
    return AppThemeDensity.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppThemeDensity.comfortable,
    );
  }
}

class AppAccentColor {
  final String id;
  final String label;
  final Color color;
  final Color softColor;

  const AppAccentColor({
    required this.id,
    required this.label,
    required this.color,
    required this.softColor,
  });
}

class AppAccentColors {
  static const blue = AppAccentColor(
    id: 'blue',
    label: '晴空蓝',
    color: Color(0xFF0071E3),
    softColor: Color(0xFFE8F2FD),
  );

  static const green = AppAccentColor(
    id: 'green',
    label: '薄荷绿',
    color: Color(0xFF16A34A),
    softColor: Color(0xFFE8FAF3),
  );

  static const orange = AppAccentColor(
    id: 'orange',
    label: '暖橙',
    color: Color(0xFFF97316),
    softColor: Color(0xFFFFF1E8),
  );

  static const purple = AppAccentColor(
    id: 'purple',
    label: '星云紫',
    color: Color(0xFF7C3AED),
    softColor: Color(0xFFF1ECFF),
  );

  static const rose = AppAccentColor(
    id: 'rose',
    label: '莓果粉',
    color: Color(0xFFE11D48),
    softColor: Color(0xFFFFEEF3),
  );

  static const graphite = AppAccentColor(
    id: 'graphite',
    label: '石墨灰',
    color: Color(0xFF475569),
    softColor: Color(0xFFF1F5F9),
  );

  static const all = [blue, green, orange, purple, rose, graphite];

  static AppAccentColor fromId(String? id) {
    return all.firstWhere((item) => item.id == id, orElse: () => blue);
  }
}

class ThemeSettings {
  final AppThemeMode mode;
  final AppAccentColor accent;
  final AppThemeDensity density;
  final bool reduceMotion;
  final bool highContrast;

  const ThemeSettings({
    this.mode = AppThemeMode.system,
    this.accent = AppAccentColors.blue,
    this.density = AppThemeDensity.comfortable,
    this.reduceMotion = false,
    this.highContrast = false,
  });

  ThemeMode get materialThemeMode {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  ThemeSettings copyWith({
    AppThemeMode? mode,
    AppAccentColor? accent,
    AppThemeDensity? density,
    bool? reduceMotion,
    bool? highContrast,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      accent: accent ?? this.accent,
      density: density ?? this.density,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'mode': mode.value,
      'accent': accent.id,
      'density': density.value,
      'reduceMotion': reduceMotion,
      'highContrast': highContrast,
    };
  }

  factory ThemeSettings.fromJson(Map<String, Object?> json) {
    return ThemeSettings(
      mode: AppThemeMode.fromValue(json['mode'] as String?),
      accent: AppAccentColors.fromId(json['accent'] as String?),
      density: AppThemeDensity.fromValue(json['density'] as String?),
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      highContrast: json['highContrast'] as bool? ?? false,
    );
  }
}

class ThemeSettingsStore {
  static const _fileName = 'theme_settings.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final settingsDir = Directory('${dir.path}/settings');
    if (!await settingsDir.exists()) {
      await settingsDir.create(recursive: true);
    }
    return File('${settingsDir.path}/$_fileName');
  }

  Future<ThemeSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const ThemeSettings();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const ThemeSettings();
      final json = jsonDecode(raw) as Map<String, Object?>;
      return ThemeSettings.fromJson(json);
    } catch (_) {
      return const ThemeSettings();
    }
  }

  Future<void> save(ThemeSettings settings) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}

class ThemeSettingsNotifier extends AsyncNotifier<ThemeSettings> {
  final _store = ThemeSettingsStore();

  @override
  Future<ThemeSettings> build() async {
    return _store.load();
  }

  Future<void> applySettings(ThemeSettings settings) async {
    state = AsyncData(settings);
    await _store.save(settings);
  }

  Future<void> setMode(AppThemeMode mode) async {
    final current = state.value ?? const ThemeSettings();
    await applySettings(current.copyWith(mode: mode));
  }

  Future<void> setAccent(AppAccentColor accent) async {
    final current = state.value ?? const ThemeSettings();
    await applySettings(current.copyWith(accent: accent));
  }

  Future<void> setDensity(AppThemeDensity density) async {
    final current = state.value ?? const ThemeSettings();
    await applySettings(current.copyWith(density: density));
  }

  Future<void> setReduceMotion(bool value) async {
    final current = state.value ?? const ThemeSettings();
    await applySettings(current.copyWith(reduceMotion: value));
  }

  Future<void> setHighContrast(bool value) async {
    final current = state.value ?? const ThemeSettings();
    await applySettings(current.copyWith(highContrast: value));
  }

  Future<void> reset() async {
    await applySettings(const ThemeSettings());
  }
}

final themeSettingsProvider =
    AsyncNotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
    );
