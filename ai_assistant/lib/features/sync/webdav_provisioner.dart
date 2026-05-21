import '../../core/security/keychain_service.dart';
import '../../data/api/profile_service.dart';
import '../../data/api/webdav_decrypt.dart';

/// WebDAV 凭据同步结果。
enum WebDavSyncStatus {
  /// 服务器未配置 WebDAV
  notConfigured,
  /// 密码解密失败（密钥不匹配或密文损坏）
  decryptFailed,
  /// 凭据保存到 Keychain 失败
  keychainFailed,
  /// 同步成功
  success,
}

class WebDavSyncResult {
  final WebDavSyncStatus status;
  final String? message;

  const WebDavSyncResult(this.status, [this.message]);

  @override
  String toString() {
    switch (status) {
      case WebDavSyncStatus.notConfigured:
        return 'WebDAV 未配置：服务器上未设置 WebDAV 账号';
      case WebDavSyncStatus.decryptFailed:
        return '解密失败：${message ?? "AES-GCM 解密 WebDAV 密码失败"}';
      case WebDavSyncStatus.keychainFailed:
        return 'Keychain 失败：${message ?? "凭据保存到本地 Keychain 失败"}';
      case WebDavSyncStatus.success:
        return '同步成功';
    }
  }
}

class WebDavProvisioner {
  /// 从服务器拉取 WebDAV 配置并保存到本地 Keychain。
  ///
  /// 返回同步结果，可用于 UI 显示。
  Future<WebDavSyncResult> syncFromServer() async {
    final profile = await ProfileService.getProfile();
    if (profile == null) {
      return const WebDavSyncResult(WebDavSyncStatus.notConfigured, '获取用户信息失败');
    }

    // 未配置 WebDAV
    if (profile.webdavUrl == null || profile.webdavUsername == null || !profile.webdavPasswordSet) {
      return const WebDavSyncResult(WebDavSyncStatus.notConfigured);
    }

    // 解密密码
    final decryptedPwd = WebDavDecrypt.decrypt(profile.webdavEncryptedPassword);
    if (decryptedPwd == null) {
      return WebDavSyncResult(WebDavSyncStatus.decryptFailed,
        'webdavUrl=${profile.webdavUrl}, encryptedPwd 长度=${profile.webdavEncryptedPassword?.length ?? 0}');
    }

    // 保存到 Keychain
    try {
      final keychain = KeychainService();
      await keychain.saveCredentials(
        profile.webdavUrl!,
        profile.webdavUsername!,
        decryptedPwd,
      );
      await keychain.setLastServerUrl(profile.webdavUrl!);

      // 回读验证
      final saved = await keychain.getCredentials(profile.webdavUrl!);
      if (saved == null) {
        return const WebDavSyncResult(WebDavSyncStatus.keychainFailed, '保存后回读为空');
      }

      return const WebDavSyncResult(WebDavSyncStatus.success);
    } catch (e) {
      return WebDavSyncResult(WebDavSyncStatus.keychainFailed, e.toString());
    }
  }

  /// 获取本地保存的 WebDAV 凭据。
  Future<Map<String, String>?> getStoredCredentials() async {
    final keychain = KeychainService();
    final lastUrl = await keychain.getLastServerUrl();
    if (lastUrl == null) return null;
    final creds = await keychain.getCredentials(lastUrl);
    if (creds == null) return null;
    return {'url': lastUrl, 'username': creds['username']!, 'password': creds['password']!};
  }
}
