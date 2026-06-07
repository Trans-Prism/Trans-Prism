import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/resource_item.dart';
import 'permission_manager.dart';

// =============================================================================
// 导出选项类型（必须定义在顶层）
// =============================================================================

/// 导出格式
enum ExportFormat { svg, png }

/// PNG 分辨率倍率
enum PngScale { x1, x2, x4 }

/// 获取倍率对应的数值
double pngScaleValue(PngScale scale) {
  switch (scale) {
    case PngScale.x1:
      return 1.0;
    case PngScale.x2:
      return 2.0;
    case PngScale.x4:
      return 4.0;
  }
}

/// 获取倍率的显示标签
String pngScaleLabel(PngScale scale) {
  switch (scale) {
    case PngScale.x1:
      return '基础 (1x)';
    case PngScale.x2:
      return '高清 (2x)';
    case PngScale.x4:
      return '超清 (4x)';
  }
}

// =============================================================================
// SvgExportService — SVG 动态导出引擎
// =============================================================================

/// SVG 动态导出引擎
///
/// 职责：
///   1. SVG 原图导出：直接读取 asset 原始文本流 → 保存为 .svg 文件
///   2. PNG 渲染导出：接收已渲染的 [ui.Image]，转为 PNG 并保存
///
/// 关于 SVG → PNG 转换的具体流程（在 [SvgPreviewScreen] 中完成）：
///   1. 使用 [RepaintBoundary] 包裹 [SvgPicture] 进行渲染
///   2. 通过 [RenderRepaintBoundary.toImage] 捕获渲染结果 → [ui.Image]
///   3. 调用本服务的 [exportPngFromImage] 进行保存
class SvgExportService {
  SvgExportService._();

  // ─── 导出主入口 ───────────────────────────────────────────────────

  /// 导出 SVG 原图（直接读取 asset 文件流并保存）
  ///
  /// [style] 可选，指定厂牌风格；不传则使用 [ResourceItem.getSvgPath] 的默认值。
  /// 返回保存后的文件路径，失败返回 null
  static Future<String?> exportSvgOriginal(ResourceItem resource,
      {String? style}) async {
    final granted = await PermissionManager().requestStoragePermission();
    if (!granted) {
      debugPrint('❌ [SvgExportService] 存储权限被拒绝');
      return null;
    }

    try {
      final svgPath = style != null
          ? resource.getSvgPath(preferredStyle: style)
          : resource.getSvgPath();
      final String svgString = await rootBundle.loadString(svgPath);
      final filename = '${resource.id}.svg';
      return _saveFile(svgString.codeUnits.toList(), filename);
    } catch (e) {
      debugPrint('❌ [SvgExportService] 读取 SVG asset 失败: $e');
      return null;
    }
  }

  /// 将已渲染的 [ui.Image] 保存为 PNG 文件
  ///
  /// [image] 通过 [RenderRepaintBoundary.toImage] 获取
  /// [resource] SVG 资源元数据（用于生成文件名）
  /// [scale] 分辨率倍率（仅用于文件名标识）
  ///
  /// 返回保存后的文件路径，失败返回 null
  static Future<String?> exportPngFromImage({
    required ui.Image image,
    required ResourceItem resource,
    required double scale,
  }) async {
    final granted = await PermissionManager().requestStoragePermission();
    if (!granted) {
      debugPrint('❌ [SvgExportService] 存储权限被拒绝');
      return null;
    }

    try {
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('图片编码失败');
      }

      final filename = '${resource.id}_${scale.toInt()}x.png';
      return _saveFile(byteData.buffer.asUint8List().toList(), filename);
    } catch (e) {
      debugPrint('❌ [SvgExportService] PNG 导出失败: $e');
      return null;
    }
  }

  // ─── 文件保存 ─────────────────────────────────────────────────────

  /// 保存 [bytes] 到设备的下载目录
  /// 公开的保存方法（供 ImageExportService / SvgPreviewScreen 调用）
  static Future<String?> saveBytes(
    List<int> bytes,
    String filename,
  ) =>
      _saveFile(bytes, filename);

  static Future<String?> _saveFile(
    List<int> bytes,
    String filename,
  ) async {
    // 优先使用下载目录，降级到文档目录
    String? savePath;
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        savePath = '${downloadsDir.path}/$filename';
      }
    } catch (_) {
      // getDownloadsDirectory 在某些平台不可用
    }

    // 降级：使用应用文档目录
    if (savePath == null) {
      final docDir = await getApplicationDocumentsDirectory();
      savePath = '${docDir.path}/$filename';
    }

    final file = File(savePath);
    await file.writeAsBytes(bytes);

    debugPrint('✅ [SvgExportService] 文件已保存: $savePath');
    return savePath;
  }
}
