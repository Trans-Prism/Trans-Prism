import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:vector_graphics/vector_graphics.dart' as vg;

/// =============================================================================
/// ImageExportService — 多格式图像导出引擎
///
/// 支持格式：PNG / JPEG / WEBP
///
/// 核心流程：
///   1. 通过 [vg.vg.loadPicture] 从 SVG 字符串解析出 [PictureInfo]
///   2. 通过 [PictureRecorder] + [Canvas] 按指定宽度等比缩放绘制到 Canvas
///   3. ⚠️ JPEG 时先绘制纯白底色，避免透明区域变黑
///   4. 通过 [picture.toImage] 栅格化为 [ui.Image]
///   5. 提取 raw RGBA 字节流
///      - PNG/JPEG: 用 [image] 库编码
///      - WEBP: 先用 [image] 编为 PNG，再用 [flutter_image_compress] 转码
/// =============================================================================
class ImageExportService {
  ImageExportService._();

  /// 支持的导出格式
  static const Set<String> supportedFormats = {'png', 'jpeg', 'webp'};

  // ─── 核心导出方法 ─────────────────────────────────────────────

  /// 将 SVG 资源导出为指定格式的位图
  ///
  /// [assetPath] SVG 资产路径
  /// [format] 输出格式：'png' / 'jpeg' / 'webp'
  /// [targetWidth] 目标宽度（像素），高度按 SVG 宽高比自动计算
  ///
  /// 返回编码后的字节数据，失败返回 null
  static Future<Uint8List?> encodeSvgToBitmap({
    required String assetPath,
    required String format,
    required double targetWidth,
  }) async {
    assert(supportedFormats.contains(format), 'Unsupported format: $format');

    try {
      // 1. 读取 SVG 原始文本
      final String svgString = await rootBundle.loadString(assetPath);
      debugPrint('📐 [ImageExportService] SVG 已读取: $assetPath');

      // 2. 通过 vg.vg.loadPicture 解析 SVG → PictureInfo
      final loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.vg.loadPicture(
        loader,
        null,
        clipViewbox: true,
      );

      final ui.Picture picture = pictureInfo.picture;
      final Size originalSize = pictureInfo.size;
      debugPrint(
          '📐 [ImageExportService] 原始尺寸: ${originalSize.width}×${originalSize.height}');

      // 3. 按 targetWidth 等比计算 targetHeight
      if (originalSize.width <= 0 || originalSize.height <= 0) {
        throw Exception('无效的 SVG 尺寸: $originalSize');
      }
      final double aspectRatio = originalSize.height / originalSize.width;
      final double targetHeight = (targetWidth * aspectRatio).ceilToDouble();

      final int w = targetWidth.ceil();
      final int h = targetHeight.ceil();
      debugPrint('📐 [ImageExportService] 目标尺寸: ${w}×${h}');

      // 4. 计算缩放倍率
      final double scale = targetWidth / originalSize.width;

      // 5. PictureRecorder + Canvas 缩放绘制
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // ⚠️ JPEG 处理：先绘制纯白背景，避免透明区变黑
      if (format == 'jpeg') {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, targetWidth, targetHeight),
          Paint()..color = Colors.white,
        );
      }

      // 缩放并绘制 SVG
      canvas.scale(scale, scale);
      canvas.drawPicture(picture);

      // 结束录制
      final ui.Picture scaledPicture = recorder.endRecording();

      // 6. 栅格化为 ui.Image
      final ui.Image image = await scaledPicture.toImage(w, h);

      // 7. 提取 raw RGBA 字节流
      final ByteData? rawBytes =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rawBytes == null) {
        throw Exception('raw RGBA 提取失败');
      }
      final Uint8List rawRgba = rawBytes.buffer.asUint8List();

      // 8. 编码
      Uint8List encoded;
      if (format == 'webp') {
        // WEBP: 先编为 PNG，再转码
        final pngBytes = _encodePngFromRgba(rawRgba, w, h);
        final result = await FlutterImageCompress.compressWithList(
          pngBytes,
          format: CompressFormat.webp,
          quality: 95,
        );
        encoded = result;
      } else {
        encoded = _encodeImageBytes(
          rawBytes: rawRgba,
          width: w,
          height: h,
          format: format,
        );
      }

      // 清理
      image.dispose();

      debugPrint(
          '✅ [ImageExportService] 编码完成: ${encoded.length} bytes, format=$format');

      // ── 控制台打印确认 ──
      // ignore: avoid_print
      print('══════════════════════════════════════════');
      // ignore: avoid_print
      print('🧪 [ImageExportService] 测试结果');
      // ignore: avoid_print
      print('  格式: $format');
      // ignore: avoid_print
      print('  尺寸: ${w}×${h}');
      // ignore: avoid_print
      print(
          '  文件大小: ${encoded.length} bytes (${(encoded.length / 1024).toStringAsFixed(1)} KB)');
      // ignore: avoid_print
      print('══════════════════════════════════════════');

      return encoded;
    } catch (e, s) {
      debugPrint('❌ [ImageExportService] 导出失败: $e');
      debugPrint('❌ [ImageExportService] 堆栈: $s');
      return null;
    }
  }

  // ─── 本地图片转换 ─────────────────────────────────────────────

  /// 将本地图片文件（SVG 或位图）转换为指定格式和分辨率
  ///
  /// 输入参数：
  ///   [filePath]      本地文件路径（支持 .svg / .png / .jpg(.jpeg) / .webp）
  ///   [targetFormat]  输出格式：'png' / 'jpeg' / 'webp'
  ///   [targetWidth]   目标宽度（像素），高度按原图宽高比自动计算
  ///
  /// 逻辑分发：
  ///   - SVG 文件：读取为 String，复用 Canvas 绘制缩放逻辑，转为目标格式
  ///   - 位图文件：使用 [File] 读取二进制 → [img.decodeImage] 解码 →
  ///     [img.copyResize] 缩放 → 编码为指定格式
  ///
  /// 返回编码后的字节数据，失败返回 null
  static Future<Uint8List?> convertLocalImage({
    required String filePath,
    required String targetFormat,
    required double targetWidth,
  }) async {
    assert(supportedFormats.contains(targetFormat),
        'Unsupported format: $targetFormat');

    try {
      if (filePath.toLowerCase().endsWith('.svg')) {
        // ─── SVG 路径 ───
        return await _convertLocalSvg(
          filePath: filePath,
          targetFormat: targetFormat,
          targetWidth: targetWidth,
        );
      } else {
        // ─── 位图路径 (PNG/JPEG/WEBP) ───
        return await _convertLocalBitmap(
          filePath: filePath,
          targetFormat: targetFormat,
          targetWidth: targetWidth,
        );
      }
    } catch (e, s) {
      debugPrint('❌ [ImageExportService] convertLocalImage 失败: $e');
      debugPrint('❌ [ImageExportService] 堆栈: $s');
      return null;
    }
  }

  /// 处理本地 SVG 文件转换（复用 Canvas 绘制缩放管线）
  static Future<Uint8List?> _convertLocalSvg({
    required String filePath,
    required String targetFormat,
    required double targetWidth,
  }) async {
    // 1. 从本地文件系统读取 SVG 原始文本
    final String svgString = File(filePath).readAsStringSync();
    debugPrint('📐 [ImageExportService] 本地 SVG 已读取: $filePath');

    // 2. 通过 vg.vg.loadPicture 解析 SVG → PictureInfo
    final loader = SvgStringLoader(svgString);
    final PictureInfo pictureInfo = await vg.vg.loadPicture(
      loader,
      null,
      clipViewbox: true,
    );

    final ui.Picture picture = pictureInfo.picture;
    final Size originalSize = pictureInfo.size;
    debugPrint(
        '📐 [ImageExportService] SVG 原始尺寸: ${originalSize.width}×${originalSize.height}');

    // 3. 按 targetWidth 等比计算 targetHeight
    if (originalSize.width <= 0 || originalSize.height <= 0) {
      throw Exception('无效的 SVG 尺寸: $originalSize');
    }
    final double aspectRatio = originalSize.height / originalSize.width;
    final double targetHeight = (targetWidth * aspectRatio).ceilToDouble();

    final int w = targetWidth.ceil();
    final int h = targetHeight.ceil();
    debugPrint('📐 [ImageExportService] SVG 目标尺寸: ${w}×${h}');

    // 4. 计算缩放倍率
    final double scale = targetWidth / originalSize.width;

    // 5. PictureRecorder + Canvas 缩放绘制
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // ⚠️ JPEG 处理：先绘制纯白背景，避免透明区变黑
    if (targetFormat == 'jpeg') {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        Paint()..color = Colors.white,
      );
    }

    canvas.scale(scale, scale);
    canvas.drawPicture(picture);

    final ui.Picture scaledPicture = recorder.endRecording();
    final ui.Image image = await scaledPicture.toImage(w, h);

    // 6. 提取 raw RGBA 字节流
    final ByteData? rawBytes =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rawBytes == null) {
      throw Exception('raw RGBA 提取失败');
    }
    final Uint8List rawRgba = rawBytes.buffer.asUint8List();

    // 7. 编码
    Uint8List encoded;
    if (targetFormat == 'webp') {
      final pngBytes = _encodePngFromRgba(rawRgba, w, h);
      final result = await FlutterImageCompress.compressWithList(
        pngBytes,
        format: CompressFormat.webp,
        quality: 95,
      );
      encoded = result;
    } else {
      encoded = _encodeImageBytes(
        rawBytes: rawRgba,
        width: w,
        height: h,
        format: targetFormat,
      );
    }

    image.dispose();

    debugPrint(
        '✅ [ImageExportService] 本地 SVG 转换完成: ${encoded.length} bytes, format=$targetFormat');
    return encoded;
  }

  /// 处理本地位图文件转换 (PNG/JPEG/WEBP)
  ///
  /// 流程：
  ///   1. [File.readAsBytesSync] 读取二进制流
  ///   2. [img.decodeImage] 解码为图像对象
  ///   3. [img.copyResize] 按 targetWidth 等比缩放（[img.Interpolation.linear]）
  ///   4. 格式编码
  ///      - JPEG：若原图含透明通道，像素逐个与纯白底色混合
  ///      - WEBP：先编码 PNG，再用 [FlutterImageCompress] 转码
  static Future<Uint8List?> _convertLocalBitmap({
    required String filePath,
    required String targetFormat,
    required double targetWidth,
  }) async {
    // 1. 读取文件二进制流
    final Uint8List fileBytes = File(filePath).readAsBytesSync();
    debugPrint(
        '📐 [ImageExportService] 本地位图已读取: $filePath (${fileBytes.length} bytes)');

    // 2. 解码为图像对象
    final img.Image? originalImage = img.decodeImage(fileBytes);
    if (originalImage == null) {
      throw Exception('图片解码失败: $filePath');
    }
    debugPrint(
        '📐 [ImageExportService] 原始尺寸: ${originalImage.width}×${originalImage.height}');

    // 3. 尺寸缩放：根据 targetWidth 等比计算高度
    if (originalImage.width <= 0) {
      throw Exception('无效的图片宽度: ${originalImage.width}');
    }
    final double aspectRatio = originalImage.height / originalImage.width;
    final int targetHeight = (targetWidth * aspectRatio).round();

    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: targetWidth.toInt(),
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
    debugPrint(
        '📐 [ImageExportService] 缩放后尺寸: ${resizedImage.width}×${resizedImage.height}');

    // 4. 格式编码
    Uint8List encoded;
    switch (targetFormat) {
      case 'png':
        encoded = img.encodePng(resizedImage);
        break;
      case 'jpeg':
        // ⚠️ JPEG 不支持透明通道：若原图含 Alpha，与纯白底色混合
        if (resizedImage.hasAlpha) {
          final img.Image whiteBg = _compositeOnWhite(resizedImage);
          encoded = img.encodeJpg(whiteBg, quality: 95);
        } else {
          encoded = img.encodeJpg(resizedImage, quality: 95);
        }
        break;
      case 'webp':
        // WEBP: 先编为 PNG，再用 flutter_image_compress 转码
        final pngBytes = img.encodePng(resizedImage);
        encoded = await FlutterImageCompress.compressWithList(
          pngBytes,
          format: CompressFormat.webp,
          quality: 95,
        );
        break;
      default:
        throw ArgumentError('Unsupported format: $targetFormat');
    }

    debugPrint(
        '✅ [ImageExportService] 本地图片转换完成: ${encoded.length} bytes, format=$targetFormat');
    return encoded;
  }

  /// 将带有 Alpha 通道的图像与纯白底色混合（为 JPEG 编码做准备）
  ///
  /// 逐像素计算：`out = src.rgba * alpha + white * (1 - alpha)`
  static img.Image _compositeOnWhite(img.Image src) {
    final img.Image dst = img.Image(
      width: src.width,
      height: src.height,
    );
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final double alpha = px.a / 255.0;
        if (alpha >= 1.0) {
          dst.setPixelRgba(x, y, px.r, px.g, px.b, 255);
        } else if (alpha <= 0.0) {
          dst.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          final int r =
              (px.r * alpha + 255 * (1.0 - alpha)).round().clamp(0, 255);
          final int g =
              (px.g * alpha + 255 * (1.0 - alpha)).round().clamp(0, 255);
          final int b =
              (px.b * alpha + 255 * (1.0 - alpha)).round().clamp(0, 255);
          dst.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }
    return dst;
  }

  // ─── 图片编码 ─────────────────────────────────────────────────

  /// 从 RGBA 字节流编码 PNG
  static Uint8List _encodePngFromRgba(Uint8List rawBytes, int w, int h) {
    final img.Image image = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rawBytes.buffer,
      numChannels: 4,
    );
    return img.encodePng(image);
  }

  /// 将 raw RGBA 字节流编码为指定格式（PNG/JPEG）
  static Uint8List _encodeImageBytes({
    required Uint8List rawBytes,
    required int width,
    required int height,
    required String format,
  }) {
    final img.Image image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rawBytes.buffer,
      numChannels: 4,
    );

    switch (format) {
      case 'png':
        return img.encodePng(image);
      case 'jpeg':
        return img.encodeJpg(image, quality: 95);
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }
}
