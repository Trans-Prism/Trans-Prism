import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// =============================================================================
/// GallerySaverService — 将图片保存到系统相册
///
/// 通过 MethodChannel 调用各平台原生 API：
///   - Android: MediaStore.Images.Media.insertImage (API 29+) /
///              MediaStore.Images.Media 旧版兼容
///   - iOS:     UIImageWriteToSavedPhotosAlbum
/// =============================================================================
class GallerySaverService {
  GallerySaverService._();

  static const _channel = MethodChannel('com.daanser.transprism/gallery_saver');

  /// 将指定路径的图片文件保存到系统相册
  ///
  /// [filePath] 本地文件的绝对路径
  /// 成功返回 true，失败抛出异常
  static Future<bool> saveImage(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'saveImage',
        {'filePath': filePath},
      );
      return result ?? false;
    } on MissingPluginException {
      // 降级：macOS/Linux/Web 等不支持平台
      debugPrint('⚠️ [GallerySaverService] 当前平台不支持保存到相册');
      return false;
    }
  }
}
