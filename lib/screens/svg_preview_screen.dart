import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/gallery_saver_service.dart';

import '../models/resource_item.dart';
import '../services/image_export_service.dart';
import '../services/permission_manager.dart';
import '../services/svg_export_service.dart';

/// =============================================================================
/// SvgPreviewScreen — 图解资源详情页（静奢风 Quiet Luxury）
///
/// 响应式布局（LayoutBuilder）：
///   - >600px：左右双栏（缩略图列表 + 预览/控制面板）
///   - ≤600px：垂直流式（预览 → 胶片选片栏 → Tags → 毛玻璃控制面板 → 底部固定按钮）
/// =============================================================================
class SvgPreviewScreen extends StatefulWidget {
  final List<ResourceItem> allResources;
  final int initialIndex;
  final String initialStyle;

  const SvgPreviewScreen({
    super.key,
    required this.allResources,
    required this.initialIndex,
    this.initialStyle = 'twemoji',
  });

  /// 单资源构造（只预览一个，列表页卡片点击时用）
  SvgPreviewScreen.single({
    super.key,
    required ResourceItem resource,
    String initialStyle = 'twemoji',
  })  : allResources = [resource],
        initialIndex = 0,
        initialStyle = initialStyle;

  @override
  State<SvgPreviewScreen> createState() => _SvgPreviewScreenState();
}

class _SvgPreviewScreenState extends State<SvgPreviewScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isExporting = false;

  late int _currentIndex;
  late String _currentStyle;
  String _selectedFormat = 'png';
  String _targetWidthStr = '1024';

  /// 自定义分辨率输入框的 TextEditingController。
  ///
  /// 作为 State 实例变量，在 [initState] 中初始化、[dispose] 中销毁，
  /// 确保热重载时 Flutter 重建对话框 Widget 不会引用已释放的 controller。
  late final TextEditingController _resController;

  ResourceItem get _currentResource => widget.allResources.isNotEmpty
      ? widget.allResources[_currentIndex]
      : widget.allResources.first;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex.clamp(0, widget.allResources.length - 1);
    _currentStyle = widget.initialStyle;
    _resController = TextEditingController(text: _targetWidthStr);
  }

  @override
  void dispose() {
    _resController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildDualPanel(context);
        }
        return _buildVerticalLayout(context);
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  平板/PC 双栏布局
  // ════════════════════════════════════════════════════════════

  Widget _buildDualPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(_currentResource.displayName)),
      bottomNavigationBar: _buildBottomActionRow(isDark),
      body: Row(
        children: [
          // 左：缩略图列表
          SizedBox(
            width: 200,
            child: _buildThumbnailList(isDark),
          ),
          // 右：预览 + 控制
          Expanded(child: _buildPreviewAndControls(isDark)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  手机垂直布局（极致压缩，无需滚动即可看到完整底部按钮）
  // ════════════════════════════════════════════════════════════

  Widget _buildVerticalLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentResource.displayName),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      // 底部按钮固定吸附在屏幕底端
      bottomNavigationBar: _buildBottomActionRow(isDark),
      body: Column(
        children: [
          // 锁定预览区高度（不让 Expanded 野蛮生长）
          SizedBox(height: 240, child: _buildPreview(isDark)),
          // 瘦身胶片栏（无灰色背景，≤60px）
          SizedBox(height: 56, child: _buildFilmStrip(isDark)),
          // Tags 标签（无重复标题，标题在 AppBar 中）
          _buildTagsBlock(isDark),
          // 毛玻璃控制面板
          _buildControlBoard(isDark),
          // 弹性空间，确保按钮始终沉底
          const Spacer(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  预览 + 控制（双栏右半部分，同步垂直布局结构）
  // ════════════════════════════════════════════════════════════

  Widget _buildPreviewAndControls(bool isDark) {
    return Column(
      children: [
        SizedBox(height: 200, child: _buildPreview(isDark)),
        SizedBox(height: 56, child: _buildFilmStrip(isDark)),
        _buildTagsBlock(isDark),
        _buildControlBoard(isDark),
        const Spacer(),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  预览舱
  // ════════════════════════════════════════════════════════════

  Widget _buildPreview(bool isDark) {
    return Center(
      child: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: Container(
          width: 220,
          height: 220,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24242C) : const Color(0xFFEDEDF0),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SvgPicture.asset(
            _currentResource.getSvgPath(preferredStyle: _currentStyle),
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  瘦身胶片选片栏（无灰色背景，选中全透明+微阴影，未选中 40%）
  // ════════════════════════════════════════════════════════════

  Widget _buildFilmStrip(bool isDark) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: widget.allResources.length,
      itemBuilder: (context, index) {
        final res = widget.allResources[index];
        final selected = index == _currentIndex;
        return GestureDetector(
          onTap: () => setState(() => _currentIndex = index),
          child: AnimatedOpacity(
            opacity: selected ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF24242C) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(6),
              child: SvgPicture.asset(
                res.getSvgPath(preferredStyle: _currentStyle),
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  缩略图列表（双栏左侧）
  // ════════════════════════════════════════════════════════════

  Widget _buildThumbnailList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: widget.allResources.length,
        itemBuilder: (context, index) {
          final res = widget.allResources[index];
          final selected = index == _currentIndex;
          return Card(
            elevation: 0,
            color: selected
                ? const Color(0xFFF5A9B8).withOpacity(0.1)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: selected
                  ? const BorderSide(color: Color(0xFFF5A9B8))
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _currentIndex = index),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: SvgPicture.asset(
                        res.getSvgPath(preferredStyle: _currentStyle),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      res.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  Tags 标签（仅灰色细小标签云，标题在 AppBar 中）
  // ════════════════════════════════════════════════════════════

  Widget _buildTagsBlock(bool isDark) {
    final secondaryTextColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8E8E93);
    final keywords = _currentResource.searchKeywords
        .where((kw) => kw != _currentResource.displayName)
        .toList();

    if (keywords.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: keywords
            .map((kw) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    kw,
                    style: TextStyle(fontSize: 10, color: secondaryTextColor),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  毛玻璃控制面板 Control Board（iOS Liquid Glass）
  // ════════════════════════════════════════════════════════════

  Widget _buildControlBoard(bool isDark) {
    final secondaryTextColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8E8E93);
    final isSvgFormat = _selectedFormat == 'svg';
    const labelWidth = 60.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 第 1 行：风格 ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        '风格',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _currentResource.styles.keys.map((style) {
                          final selected = _currentStyle == style;
                          return ChoiceChip(
                            label: Text(_styleName(style),
                                style: const TextStyle(fontSize: 11)),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _currentStyle = style),
                            visualDensity: VisualDensity.compact,
                            selectedColor:
                                const Color(0xFFF5A9B8).withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: selected
                                  ? const Color(0xFFF5A9B8)
                                  : secondaryTextColor,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFF5A9B8)
                                  : (isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── 第 2 行：格式 ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        '格式',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: ['svg', 'png', 'jpeg', 'webp'].map((f) {
                          final sel = _selectedFormat == f;
                          return ChoiceChip(
                            label: Text(f.toUpperCase(),
                                style: const TextStyle(fontSize: 11)),
                            selected: sel,
                            onSelected: (_) =>
                                setState(() => _selectedFormat = f),
                            visualDensity: VisualDensity.compact,
                            selectedColor:
                                const Color(0xFFF5A9B8).withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: sel
                                  ? const Color(0xFFF5A9B8)
                                  : secondaryTextColor,
                            ),
                            side: BorderSide(
                              color: sel
                                  ? const Color(0xFFF5A9B8)
                                  : (isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                // ── 第 3 行：分辨率（SVG 格式时隐藏）──
                if (!isSvgFormat) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          '分辨率',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ...[512, 1024, 2048].map((size) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text('$size',
                                        style: const TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      setState(() {
                                        _targetWidthStr = size.toString();
                                      });
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )),
                            // 自定义值按钮：带 ✏️ 图标的描边样式，与预设实心 Chip 区分
                            SizedBox(
                              height: 32,
                              child: OutlinedButton.icon(
                                onPressed: () => _showCustomWidthDialog(),
                                icon: const Icon(Icons.edit_outlined, size: 13),
                                label: Text(
                                  '${_targetWidthStr}px',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: secondaryTextColor,
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  底部动作区：双按钮（固定在 bottomNavigationBar）
  // ════════════════════════════════════════════════════════════

  Widget _buildBottomActionRow(bool isDark) {
    const themeColor = Color(0xFFF5A9B8);
    final isSvgFormat = _selectedFormat == 'svg';

    Widget buildFileButton() => SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : _handleExportToFile,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text(
              '保存到文件',
              style: TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: themeColor,
              side: BorderSide(color: themeColor.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

    Widget buildAlbumButton() => SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _handleExportToAlbum,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: const Text(
              '保存到相册',
              style: TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF24242C) : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        top: false,
        child: isSvgFormat
            // SVG 格式：仅显示"保存到文件"（全宽）
            ? buildFileButton()
            // 非 SVG 格式：双按钮（flex 2:3 防挤压）
            : Row(
                children: [
                  Expanded(flex: 2, child: buildFileButton()),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: buildAlbumButton()),
                ],
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  导出逻辑
  // ════════════════════════════════════════════════════════════

  /// 保存到相册（直接写入系统相册）
  Future<void> _handleExportToAlbum() async {
    if (!await PermissionManager().checkStoragePermission()) {
      final granted = await PermissionManager().requestStoragePermission();
      if (!granted) {
        setState(() => _isExporting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要存储权限才能保存到相册'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isExporting = true);

    try {
      final savedPath = await _performExport();
      if (!mounted) return;

      if (savedPath != null && _selectedFormat != 'svg') {
        // ── 直接保存到系统相册 ──
        try {
          final saved = await GallerySaverService.saveImage(savedPath);
          if (!mounted) return;
          if (saved) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ 已保存到相册'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✅ 已保存(可前往文件管理器查看): $savedPath'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ));
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ 已保存(可前往文件管理器查看): $savedPath'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        }
      } else if (savedPath != null) {
        // SVG 格式：只保存到文件
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ 已保存: $savedPath'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('导出失败'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('导出出错: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  /// 保存到文件（直接保存到设备下载目录）
  Future<void> _handleExportToFile() async {
    if (!await PermissionManager().checkStoragePermission()) {
      final granted = await PermissionManager().requestStoragePermission();
      if (!granted) {
        setState(() => _isExporting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要存储权限才能保存文件'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isExporting = true);

    try {
      final savedPath = await _performExport();
      if (!mounted) return;

      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ 已保存: $savedPath'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('导出失败'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('导出出错: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  /// 执行实际的导出操作（按当前配置生成文件）
  Future<String?> _performExport() async {
    final svgPath = _currentResource.getSvgPath(preferredStyle: _currentStyle);
    final width = double.tryParse(_targetWidthStr) ?? 1024;

    if (_selectedFormat == 'svg') {
      final svgString = await rootBundle.loadString(svgPath);
      return SvgExportService.saveBytes(
        svgString.codeUnits.toList(),
        '${_currentResource.id}.svg',
      );
    } else {
      final bytes = await ImageExportService.encodeSvgToBitmap(
        assetPath: svgPath,
        format: _selectedFormat,
        targetWidth: width,
      );
      if (bytes != null) {
        return SvgExportService.saveBytes(
          bytes.toList(),
          '${_currentResource.id}_${width.toInt()}w.$_selectedFormat',
        );
      }
      return null;
    }
  }

  /// 弹出自定义分辨率输入对话框
  ///
  /// 使用 State 实例变量 [_resController] 而非局部 TextEditingController，
  /// 避免热重载时对话框 Widget 重建导致「used after being disposed」崩溃。
  Future<void> _showCustomWidthDialog() async {
    if (!mounted) return;

    // 同步当前分辨率到 controller 文本（用户可能已通过预设按钮更改过值）
    _resController.text = _targetWidthStr;

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('自定义分辨率'),
          content: TextField(
            controller: _resController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '宽度 (px)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _resController.text),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        setState(() {
          _targetWidthStr = result;
        });
      }
    } catch (_) {
      // 忽略异步间隙后的 context 错误
    }
  }

  String _styleName(String id) {
    switch (id) {
      case 'twemoji':
        return 'Twemoji';
      case 'openmoji':
        return 'OpenMoji';
      case 'noto':
        return 'Noto';
      default:
        return id;
    }
  }
}
