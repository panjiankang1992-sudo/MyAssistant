import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';

class UserProfile {
  final String name;
  final String email;
  final String phone;
  final int avatarColorIndex;
  final String? avatarEmoji;
  final String? avatarPath;
  final String? avatarValue;
  final String? serverAvatarUrl;
  final int version;

  const UserProfile({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.avatarColorIndex = 0,
    this.avatarEmoji,
    this.avatarPath,
    this.avatarValue,
    this.serverAvatarUrl,
    this.version = 1,
  });

  String get avatarLetter {
    if (serverAvatarUrl != null && serverAvatarUrl!.isNotEmpty) return '';
    if (avatarPath != null && avatarPath!.isNotEmpty) return '';
    if (avatarEmoji != null && avatarEmoji!.isNotEmpty) return avatarEmoji!;
    if (name.isEmpty) return '?';
    return name.substring(0, 1);
  }

  bool get hasCustomAvatar => avatarPath != null && avatarPath!.isNotEmpty;

  bool get hasServerAvatar =>
      serverAvatarUrl != null && serverAvatarUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'avatarColorIndex': avatarColorIndex,
    'avatarEmoji': avatarEmoji,
    'avatarPath': avatarPath,
    'avatarValue': avatarValue,
    'serverAvatarUrl': serverAvatarUrl,
    'version': version,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
    avatarColorIndex: json['avatarColorIndex'] ?? 0,
    avatarEmoji: json['avatarEmoji'],
    avatarPath: json['avatarPath'],
    avatarValue: json['avatarValue'],
    serverAvatarUrl: json['serverAvatarUrl'],
    version: json['version'] ?? 1,
  );

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    int? avatarColorIndex,
    String? avatarEmoji,
    String? avatarPath,
    String? avatarValue,
    String? serverAvatarUrl,
    bool clearAvatar = false,
    bool clearServerAvatar = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      avatarEmoji: clearAvatar ? null : (avatarEmoji ?? this.avatarEmoji),
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarValue: clearAvatar ? null : (avatarValue ?? this.avatarValue),
      serverAvatarUrl: clearServerAvatar
          ? null
          : (serverAvatarUrl ?? this.serverAvatarUrl),
      version: version + 1,
    );
  }
}

class ProfileNotifier extends Notifier<UserProfile> {
  static const _keyProfile = 'profile_cache';

  @override
  UserProfile build() {
    // 启动时从本地缓存恢复个人信息
    _loadFromCache();
    return const UserProfile();
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await ref
          .read(datasourceProvider)
          .getAppSettingJson('user_profile', _keyProfile);
      if (cached != null && cached.isNotEmpty) {
        state = UserProfile.fromJson(cached);
      }
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      await ref
          .read(datasourceProvider)
          .upsertAppSettingJson(
            module: 'profile',
            dataType: 'user_profile',
            id: _keyProfile,
            payload: state.toJson(),
          );
    } catch (_) {}
  }

  void updateProfile({String? name, String? email, String? phone}) {
    state = state.copyWith(name: name, email: email, phone: phone);
    _saveToCache();
  }

  void updateAvatar({int? colorIndex, String? emoji}) {
    state = state.copyWith(avatarColorIndex: colorIndex, avatarEmoji: emoji);
    _saveToCache();
  }

  void setAvatarPath(String path) {
    state = state.copyWith(avatarPath: path, avatarValue: 'file:$path');
    _saveToCache();
  }

  void setAvatarValue(String value) {
    final normalized = value.trim();
    final filePath = normalized.startsWith('file:')
        ? normalized.replaceFirst('file:', '')
        : null;
    state = state.copyWith(
      avatarValue: normalized,
      avatarPath: filePath,
      clearServerAvatar: true,
    );
    _saveToCache();
  }

  void clearAvatar() {
    state = state.copyWith(clearAvatar: true);
    _saveToCache();
  }

  void loadFromCloud(Map<String, dynamic> json) {
    state = UserProfile.fromJson(json);
    _saveToCache();
  }

  void updateFromServer(Map<String, dynamic> data) {
    final nickname = data['nickname'] as String? ?? '';
    final username = data['username'] as String? ?? '';
    final avatar = (data['avatar'] as String? ?? '').trim();
    final isCatalogAvatar =
        avatar.startsWith('preset:') ||
        avatar.startsWith('emoji:') ||
        avatar.startsWith('file:');
    state = UserProfile(
      name: nickname.isNotEmpty ? nickname : username,
      email: data['email'] as String? ?? state.email,
      phone: data['phone'] as String? ?? state.phone,
      avatarColorIndex: state.avatarColorIndex,
      avatarEmoji: avatar.startsWith('emoji:')
          ? avatar.replaceFirst('emoji:', '')
          : null,
      avatarPath: avatar.startsWith('file:')
          ? avatar.replaceFirst('file:', '')
          : null,
      avatarValue: isCatalogAvatar ? avatar : null,
      serverAvatarUrl: !isCatalogAvatar && avatar.isNotEmpty ? avatar : null,
      version: state.version + 1,
    );
    _saveToCache();
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);
