import 'api_client.dart';

class ProfileService {
  static Future<ProfileData?> getProfile() async {
    final resp = await ApiClient.get('/api/public/profile');
    if (!resp.isSuccess || resp.data == null) return null;
    final d = resp.data!;
    return ProfileData(
      id: d['id'] as int,
      username: d['username'] as String,
      nickname: d['nickname'] as String? ?? '',
      avatar: d['avatar'] as String?,
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      gender: d['gender'] as int?,
      birthday: d['birthday'] as String?,
      address: d['address'] as String?,
      hobbies: d['hobbies'] as String?,
      signature: d['signature'] as String?,
      webdavType: d['webdavType'] as String?,
      webdavUrl: d['webdavUrl'] as String?,
      webdavUsername: d['webdavUsername'] as String?,
      webdavEncryptedPassword: d['webdavEncryptedPassword'] as String?,
      webdavPasswordSet: d['webdavPasswordSet'] as bool? ?? false,
    );
  }

  static Future<bool> updateProfile(Map<String, dynamic> fields) async {
    final resp = await ApiClient.put('/api/public/profile', fields);
    return resp.isSuccess;
  }
}

class ProfileData {
  final int id;
  final String username;
  final String nickname;
  final String? avatar;
  final String email;
  final String phone;
  final int? gender;
  final String? birthday;
  final String? address;
  final String? hobbies;
  final String? signature;
  final String? webdavType;
  final String? webdavUrl;
  final String? webdavUsername;
  final String? webdavEncryptedPassword;
  final bool webdavPasswordSet;

  ProfileData({
    required this.id, required this.username, required this.nickname,
    this.avatar, required this.email, required this.phone,
    this.gender, this.birthday, this.address, this.hobbies, this.signature,
    this.webdavType, this.webdavUrl, this.webdavUsername,
    this.webdavEncryptedPassword, required this.webdavPasswordSet,
  });
}
