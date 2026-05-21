import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// AES-256-GCM 解密工具。
///
/// 密文格式（与后端 AesEncryptUtils 兼容）：
/// Base64( IV[12] || ciphertext || GCM-Tag[16] )
class WebDavDecrypt {
  static const _keyB64 = 'CJ0Xkfbp2KtWq0uZ0ckCCtGIOZU7NPC9ZXenbcZGZG8=';
  static const _ivLength = 12;
  static const _tagBits = 128;

  /// 解密 AES-256-GCM 密文。
  ///
  /// 返回解密后的明文，失败时返回 null。
  static String? decrypt(String? cipherB64) {
    if (cipherB64 == null || cipherB64.isEmpty) return null;
    try {
      final keyBytes = base64Decode(_keyB64);
      final decoded = base64Decode(cipherB64);

      if (decoded.length < _ivLength + 16) {
        // 密文过短，至少需要 IV(12) + Tag(16)
        return null;
      }

      final iv = Uint8List.fromList(decoded.sublist(0, _ivLength));
      final cipherAndTag = Uint8List.fromList(decoded.sublist(_ivLength));

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(keyBytes), _tagBits, iv, Uint8List(0)),
        );

      // processBytes + doFinal 是 PointyCastle AEAD 解密的正确方式。
      // 单次 processBlock 无法正确处理 GCM 认证标签，会抛异常。
      final out = Uint8List(cipher.getOutputSize(cipherAndTag.length));
      final len = cipher.processBytes(cipherAndTag, 0, cipherAndTag.length, out, 0);
      final finalLen = cipher.doFinal(out, len);

      final decrypted = Uint8List.sublistView(out, 0, len + finalLen);
      return utf8.decode(decrypted);
    } on InvalidCipherTextException {
      // GCM 认证失败——密文被篡改或密钥不匹配
      return null;
    } catch (e) {
      return null;
    }
  }
}
