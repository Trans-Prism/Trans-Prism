import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../services/image_export_service.dart';
import '../services/permission_manager.dart';
import '../services/svg_export_service.dart';

/// =============================================================================
/// ImageConverterScreen — 本地图片格式转换器（Quiet Luxury 静奢风）
///
/// 核心流程：
///   1. 初始态：虚线框 + 上传按钮，引导用户选择本地图片
///   2. 加载预览：SVG → [SvgPicture.file] / 位图 → [Image.file]
///   3. 毛玻璃控制台：选择导出格式（位图输入时 SVG 置灰） + 分辨率
///   4. 导出：绑定 [ImageExportService.convertLocalImage]
/// =============================================================================
class ImageConverterScreen extends StatefulWidget {
  const ImageConverterScreen({super.key});

  @override
  State<ImageConverterScreen> createState() => _ImageConverterScreenState();
}

class _ImageConverterScreenState extends State<ImageConverterScreen> {
  /// 用户选择的本地文件（null = 未选择）
  PlatformFile? _selectedFile;

  /// 导出格式
  String _selectedFormat = 'png';

  /// 目标宽度（像素）
  String _targetWidthStr = '1024';

  /// 导出中标记
  bool _isExporting = false;

  /// 自定义分辨率输入框的 Controller
  late final TextEditingController _resController;

  // ── 派生属性 ──

  /// 输入文件是否为 SVG
  bool get _isSvgInput =>
      _selectedFile != null &&
      _selectedFile!.name.toLowerCase().endsWith('.svg');

  /// 输入文件是否为位图
  bool get _isBitmapInput => _selectedFile != null && !_isSvgInput;

  /// 当前选择的导出格式是否为 SVG（仅 SVG 输入时可选）
  bool get _isSvgFormat => _selectedFormat == 'svg';

  @override
  void initState() {
    super.initState();
    _resController = TextEditingController(text: _targetWidthStr);
  }

  @override
  void dispose() {
    _resController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF5F5F7)
        : const Color(0xFF1D1D1F);

    return Scaffold(
      appBar: AppBar(
        title: Text('图片格式转换', style: TextStyle(color: textColor)),
      ),
      body: _selectedFile == null
          ? _buildInitialState(isDark)
          : _buildEditor(isDark),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  初始态：虚线框 + 上传按钮
  // ════════════════════════════════════════════════════════════

  Widget _buildInitialState(bool isDark) {
    return Center(
      child: GestureDetector(
        onTap: _pickFile,
        child: Container(
          width: 260,
          height: 260,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.grey.withOpacity(0.04),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file_rounded,
                size: 56,
                color: isDark
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '选择 SVG, PNG, JPEG 或 WEBP 文件',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withOpacity(0.45)
                        : Colors.grey.withOpacity(0.55),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5BCEFA).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_outlined,
                      size: 18,
                      color: Color(0xFF5BCEFA),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '浏览文件',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5BCEFA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  文件选择后：预览 + 控制面板
  // ════════════════════════════════════════════════════════════

  Widget _buildEditor(bool isDark) {
    return Column(
      children: [
        // 预览区域
        _buildPreview(isDark),
        // 文件名信息
        _buildFileInfo(isDark),
        // 毛玻璃控制面板
        _buildControlBoard(isDark),
        const Spacer(),
        // 底部动作按钮
        _buildBottomActionRow(isDark),
      ],
    );
  }

  /// 图片预览
  Widget _buildPreview(bool isDark) {
    if (_selectedFile?.bytes == null) return const SizedBox.shrink();

    Widget preview;
    if (_isSvgInput) {
      final svgContent = String.fromCharCodes(_selectedFile!.bytes!);
      preview = SvgPicture.string(svgContent, fit: BoxFit.contain);
    } else {
      preview = Image.memory(_selectedFile!.bytes!, fit: BoxFit.contain);
    }

    return Container(
      height: 240,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: preview,
    );
  }

  /// 文件信息栏
  Widget _buildFileInfo(bool isDark) {
    if (_selectedFile == null) return const SizedBox.shrink();

    final file = _selectedFile!;
    final fileSizeStr = _formatFileSize(file.size);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(
            _isSvgInput ? Icons.code : Icons.image_outlined,
            size: 16,
            color: isDark ? const Color(0xFF98989E) : const Color(0xFF8E8E93),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              file.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF98989E)
                    : const Color(0xFF8E8E93),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            fileSizeStr,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF636366) : const Color(0xFFAEAEB2),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _selectedFile = null;
              _selectedFormat = 'png';
            }),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? const Color(0xFF636366) : const Color(0xFFAEAEB2),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  毛玻璃控制面板（复用 svg_preview_screen 的 Liquid Glass 风格）
  // ════════════════════════════════════════════════════════════

  Widget _buildControlBoard(bool isDark) {
    final secondaryTextColor = isDark
        ? const Color(0xFF98989E)
        : const Color(0xFF8E8E93);
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
                // ── 第 1 行：格式 ──
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
                          // 位图输入时 SVG 选项置灰禁用（onSelected 传 null）
                          final disabled = _isBitmapInput && f == 'svg';
                          return ChoiceChip(
                            label: Text(
                              f.toUpperCase(),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: sel,
                            onSelected: disabled
                                ? null
                                : (_) => setState(() => _selectedFormat = f),
                            visualDensity: VisualDensity.compact,
                            selectedColor: const Color(
                              0xFF5BCEFA,
                            ).withOpacity(0.15),
                            disabledColor: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.grey.withOpacity(0.05),
                            labelStyle: TextStyle(
                              color: disabled
                                  ? (isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300)
                                  : sel
                                  ? const Color(0xFF5BCEFA)
                                  : secondaryTextColor,
                            ),
                            side: BorderSide(
                              color: disabled
                                  ? Colors.transparent
                                  : sel
                                  ? const Color(0xFF5BCEFA)
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

                // ── 第 2 行：分辨率（SVG 导出格式时隐藏）──
                if (!_isSvgFormat) ...[
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
                            ...[512, 1024, 2048].map(
                              (size) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(
                                    '$size',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _targetWidthStr = size.toString();
                                    });
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            // 自定义值按钮
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
                                    horizontal: 10,
                                  ),
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
  //  底部动作按钮
  // ════════════════════════════════════════════════════════════

  Widget _buildBottomActionRow(bool isDark) {
    const themeColor = Color(0xFF5BCEFA);

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
            borderRadius: BorderRadius.circular(12),
          ),
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
                  strokeWidth: 2,
                  color: Colors.white,
                ),
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
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _isSvgFormat
            ? buildFileButton()
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
  //  文件选择
  // ════════════════════════════════════════════════════════════

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          // 位图输入时默认选中 png，且禁用 SVG 格式；SVG 输入默认保留上次选择
          if (_selectedFile!.name.toLowerCase().endsWith('.svg') == false) {
            if (_selectedFormat == 'svg') {
              _selectedFormat = 'png';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [ImageConverter] 文件选择失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件选择失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //  导出逻辑
  // ════════════════════════════════════════════════════════════

  /// 保存到相册（通过系统分享让用户存入相册）
  Future<void> _handleExportToAlbum() async {
    if (!await _ensurePermission()) return;

    setState(() => _isExporting = true);

    try {
      final savedPath = await _performExport();
      if (!mounted) return;

      if (savedPath != null) {
        try {
          final xFile = XFile(savedPath);
          await Share.shareXFiles([xFile], text: '转换图片 - $_selectedFormat');
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 已保存(可前往文件管理器查看): $savedPath'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导出失败'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出出错: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  /// 保存到文件（直接保存到设备下载目录）
  Future<void> _handleExportToFile() async {
    if (!await _ensurePermission()) return;

    setState(() => _isExporting = true);

    try {
      final savedPath = await _performExport();
      if (!mounted) return;

      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已保存: $savedPath'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导出失败'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出出错: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  /// 执行实际的导出操作
  Future<String?> _performExport() async {
    if (_selectedFile?.bytes == null) return null;

    final fileBytes = _selectedFile!.bytes!;
    final baseName = _selectedFile!.name;
    // 去除原扩展名
    final nameWithoutExt = baseName.contains('.')
        ? baseName.substring(0, baseName.lastIndexOf('.'))
        : baseName;
    final width = double.tryParse(_targetWidthStr) ?? 1024;

    if (_isSvgFormat) {
      // SVG 导出：直接使用已有字节
      return SvgExportService.saveBytes(
        fileBytes.toList(),
        '$nameWithoutExt.svg',
      );
    } else {
      // 位图导出：调用 ImageExportService.convertLocalImageBytes（Web 兼容）
      final bytes = await ImageExportService.convertLocalImageBytes(
        fileName: _selectedFile!.name,
        fileBytes: fileBytes,
        targetFormat: _selectedFormat,
        targetWidth: width,
      );
      if (bytes != null) {
        return SvgExportService.saveBytes(
          bytes.toList(),
          '${nameWithoutExt}_${width.toInt()}w.$_selectedFormat',
        );
      }
      return null;
    }
  }

  /// 检查并请求存储权限
  Future<bool> _ensurePermission() async {
    if (!await PermissionManager().checkStoragePermission()) {
      final granted = await PermissionManager().requestStoragePermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要存储权限才能保存文件'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  // ════════════════════════════════════════════════════════════
  //  自定义分辨率对话框
  // ════════════════════════════════════════════════════════════

  Future<void> _showCustomWidthDialog() async {
    if (!mounted) return;

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

  // ════════════════════════════════════════════════════════════
  //  工具方法
  // ════════════════════════════════════════════════════════════

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
