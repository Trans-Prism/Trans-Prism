import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'models/gender_identity.dart';
import 'screens/about_screen.dart';
import 'screens/bra_calculator_page.dart';
import 'screens/disclaimer_page.dart';
import 'screens/disclaimer_view_screen.dart';
import 'screens/hormone_converter_screen.dart';
import 'screens/image_converter_screen.dart';
import 'screens/medical_directory/medical_directory_list_screen.dart';
import 'screens/tracker_screen.dart';
import 'services/tracker_update_service.dart';
import 'screens/svg_resource_gallery_screen.dart';
import 'screens/voice_training/voice_training_home.dart';
import 'screens/wiki_tab.dart';
import 'screens/workspace_tab.dart';
import 'services/home_module_visibility.dart';
import 'services/image_export_service.dart';
import 'services/resource_service.dart';
import 'services/notification_service.dart';
import 'services/permission_manager.dart';
import 'services/update_service.dart';
import 'services/wiki_sync_service.dart';
import 'services/theme_service.dart';
import 'widgets/gradient_icon.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/medication_stock_summary.dart';
import 'widgets/update_dialog.dart';
import 'widgets/battery_optimization_guide_card.dart';
import 'storage/disclaimer_repository.dart';
import 'storage/gender_identity_repository.dart';
import 'utils/data_migration_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const TransToolboxApp());
}

/// 构建亮色主题 — 温润纸张 · 呼吸感
///
/// 设计 Token：
///   surface       #F9F8F6  燕麦暖纸底（消除临床感）
///   card          #FFFFFF  仅柔弥散阴影，无边框
///   text-primary  #333333  深灰（非刺眼纯黑）
///   text-secondary#8A8A86  细腻浅灰
///   accent        #F5A9B8  跨性别旗帜粉（品牌色）
ThemeData _buildLightTheme(Color primaryColor) {
  return ThemeData(
    scaffoldBackgroundColor: const Color(0xFFF9F8F6),
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: primaryColor.computeLuminance() > 0.5
          ? const Color(0xFF3A1A22)
          : Colors.white,
      secondary: primaryColor,
      onSecondary: const Color(0xFF3A1A22),
      surface: const Color(0xFFF9F8F6),
      onSurface: const Color(0xFF333333),
      error: const Color(0xFFC44A4A),
      onError: Colors.white,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: Color(0xFF333333),
        height: 1.2,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF333333),
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Color(0xFF4A4A4A),
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF6A6A66),
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Color(0xFF9A9A96),
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A8A86),
        height: 1.4,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF8E8E96),
        height: 1.3,
        letterSpacing: 0.3,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF9F8F6),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
        fontSize: 22,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFF333333)),
      actionsIconTheme: IconThemeData(color: Color(0xFF333333)),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF8A8A86)),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFF9F8F6),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: primaryColor,
            height: 1.3,
          );
        }
        return const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Color(0xFF8A8A86),
          height: 1.3,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primaryColor, size: 24);
        }
        return const IconThemeData(color: Color(0xFF8A8A86), size: 24);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8E8E5),
      thickness: 0.5,
      space: 1,
    ),
    useMaterial3: true,
  );
}

/// 构建暗色主题 — 温润暖夜 · 呼吸感
ThemeData _buildDarkTheme(Color primaryColor) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1C1C1A),
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: primaryColor.computeLuminance() > 0.5
          ? const Color(0xFF3A1A22)
          : Colors.white,
      secondary: primaryColor,
      onSecondary: const Color(0xFF3A1A22),
      surface: const Color(0xFF1C1C1A),
      onSurface: const Color(0xFFEDEDF0),
      error: const Color(0xFFE57373),
      onError: const Color(0xFF1A1A1A),
    ),
    // ── 文字主题 ──
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: Color(0xFFEDEDF0),
        height: 1.2,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFFEDEDF0),
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Color(0xFFEDEDF0),
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFFEDEDF0),
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Color(0xFFEDEDF0),
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFFC8C8CC),
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Color(0xFF7A7A82),
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7A7A82),
        height: 1.4,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF6B6B76),
        height: 1.3,
        letterSpacing: 0.3,
      ),
    ),
    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1C1C1A),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFFEDEDF0),
        fontSize: 22,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFFEDEDF0)),
      actionsIconTheme: IconThemeData(color: Color(0xFFEDEDF0)),
    ),
    // ── 图标主题 ──
    iconTheme: const IconThemeData(color: Color(0xFF8E8E96)),
    primaryIconTheme: const IconThemeData(color: Color(0xFFEDEDF0)),
    // ── 卡片（去边框，仅柔弥散阴影） ──
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFF24242C),
      margin: EdgeInsets.zero,
    ),
    // ── 底部导航栏 ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1C1C1A),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          );
        }
        return const TextStyle(fontSize: 11, color: Color(0xFF6B6B76));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: primaryColor);
        }
        return const IconThemeData(color: Color(0xFF6B6B76));
      }),
    ),
    // ── 底部应用栏 ──
    bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xFF1C1C1A)),
    // ── 对话框 ──
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF24242C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFEDEDF0),
      ),
      contentTextStyle: const TextStyle(fontSize: 14, color: Color(0xFF8E8E96)),
    ),
    // ── 输入框 ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF24242C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333338)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333338)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor),
      ),
      labelStyle: const TextStyle(color: Color(0xFF8E8E96)),
      hintStyle: const TextStyle(color: Color(0xFF6B6B76)),
    ),
    // ── 下拉菜单 ──
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF24242C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333338)),
        ),
      ),
    ),
    // ── 弹出菜单 ──
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF24242C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(color: Color(0xFFEDEDF0), fontSize: 14),
    ),
    // ── 菜单按钮 ──
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF24242C)),
      ),
    ),
    // ── 开关 ──
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.grey.shade500;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withValues(alpha: 0.3);
        }
        return const Color(0xFF333338);
      }),
    ),
    // ── Chip ──
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF24242C),
      labelStyle: const TextStyle(color: Color(0xFFEDEDF0)),
      secondaryLabelStyle: const TextStyle(color: Color(0xFF8E8E96)),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // ── 按钮 ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: const Color(0xFFEDEDF0),
        backgroundColor: primaryColor,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryColor),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEDEDF0),
        side: const BorderSide(color: Color(0xFF333338)),
      ),
    ),
    // ── 复选框、单选按钮 ──
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all(Colors.white),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return const Color(0xFF333338);
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return const Color(0xFF8E8E96);
      }),
    ),
    // ── 进度条 ──
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaryColor,
      circularTrackColor: Color(0xFF333338),
      linearTrackColor: Color(0xFF333338),
    ),
    // ── 分隔线 ──
    dividerTheme: const DividerThemeData(color: Color(0xFF333338), space: 1),
    // ── 时间选择器、日期选择器 ──
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xFF24242C),
      headerBackgroundColor: const Color(0xFF1C1C1A),
      headerForegroundColor: const Color(0xFFEDEDF0),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return const Color(0xFFEDEDF0);
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return null;
      }),
      todayForegroundColor: WidgetStateProperty.all(primaryColor),
      surfaceTintColor: Colors.transparent,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: const Color(0xFF24242C),
      hourMinuteColor: const Color(0xFF1C1C1A),
      hourMinuteTextColor: const Color(0xFFEDEDF0),
      dayPeriodTextColor: const Color(0xFFEDEDF0),
      dialHandColor: primaryColor,
      dialBackgroundColor: const Color(0xFF1C1C1A),
      dialTextColor: const Color(0xFFEDEDF0),
      entryModeIconColor: primaryColor,
    ),
    // ── 提示框 ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF24242C),
      contentTextStyle: const TextStyle(color: Color(0xFFEDEDF0)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    // ── 工具提示 ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF24242C),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Color(0xFFEDEDF0), fontSize: 12),
    ),
    // ── BottomSheet ──
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1C1C1A),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    // ── TabBar ──
    tabBarTheme: TabBarThemeData(
      labelColor: primaryColor,
      unselectedLabelColor: const Color(0xFF6B6B76),
      indicatorColor: primaryColor,
    ),
  );
}

/// 根应用 — StatefulWidget 以响应 ThemeService 的变化
class TransToolboxApp extends StatefulWidget {
  const TransToolboxApp({super.key});

  @override
  State<TransToolboxApp> createState() => _TransToolboxAppState();
}

class _TransToolboxAppState extends State<TransToolboxApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Trans Prism',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(_themeService.themeColor),
          darkTheme: _buildDarkTheme(_themeService.themeColor),
          themeMode: _themeService.themeMode,
          home: AppRootController(themeService: _themeService),
        );
      },
    );
  }
}

class AppRootController extends StatefulWidget {
  final ThemeService themeService;

  const AppRootController({super.key, required this.themeService});

  @override
  State<AppRootController> createState() => _AppRootControllerState();
}

class _AppRootControllerState extends State<AppRootController> {
  final GenderIdentityRepository _genderRepository = GenderIdentityRepository();
  final DisclaimerRepository _disclaimerRepository = DisclaimerRepository();
  String? _genderIdentity;
  bool _disclaimerAccepted = false;
  bool _isLoading = true;

  // 用户问候设置
  String _greetingName = '伙伴';
  String _namePrefix = ''; // '' = 不显示

  static const _prefsGreetingName = 'user_greeting_name';
  static const _prefsNamePrefix = 'user_name_prefix';

  @override
  void initState() {
    super.initState();
    _loadAppState();
    _loadGreetingSettings();
    WikiSyncService.instance.syncAllInBackground();
    TrackerUpdateService.instance.checkAndUpdate();
    _initNotifications();
    _initResourceService();
  }

  Future<void> _initNotifications() async {
    // 1. 初始化 Chronos 通知引擎
    await NotificationService().initialize();

    // 2. 请求基础通知权限（Android 13+）
    await NotificationService().requestPermission();

    // 3. 批量请求所有关键保活权限（通知 + 精确闹钟 + 忽略电池优化）
    final permResult =
        await PermissionManager().requestAllCriticalPermissions();
    debugPrint('📋 [main] 权限请求总览: $permResult');
  }

  /// 初始化 JSON 驱动的资源服务并运行搜索测试
  Future<void> _initResourceService() async {
    await ResourceService().initialize();

    // ── 控制台测试：验证数据解析与搜索逻辑 ──
    final svc = ResourceService();
    debugPrint('══════════════════════════════════════════');
    debugPrint('🧪 [ResourceService] 搜索测试开始');
    debugPrint('📊 总资源数: ${svc.allResources.length}');

    // 测试 1：空查询 → 全量
    final all = svc.searchResources('');
    debugPrint('📋 空查询返回: ${all.length} 条');

    // 测试 2：中文搜索
    final cnResult = svc.searchResources('蝴蝶');
    debugPrint('🔍 搜索"蝴蝶": ${cnResult.map((r) => r.displayName).toList()}');

    // 测试 3：英文搜索
    final enResult = svc.searchResources('pill');
    debugPrint('🔍 搜索"pill": ${enResult.map((r) => r.displayName).toList()}');

    // 测试 4：Emoji 搜索
    final emojiResult = svc.searchResources('🦈');
    debugPrint('🔍 搜索"🦈": ${emojiResult.map((r) => r.displayName).toList()}');

    // 测试 5：getSvgPath fallback
    final transSym = svc.searchResources('trans symbol').firstOrNull;
    debugPrint(
      '📁 trans_symbol twemoji path: ${transSym?.getSvgPath(preferredStyle: "twemoji") ?? 'N/A'}',
    );
    debugPrint(
      '📁 trans_symbol openmoji fallback: ${transSym?.getSvgPath(preferredStyle: "openmoji") ?? 'N/A'}',
    );

    // 测试 6：无结果
    final noResult = svc.searchResources('zzzznotfound');
    debugPrint('🔍 搜索"zzzznotfound": ${noResult.length} 条');
    debugPrint('🧪 [ResourceService] 搜索测试完成');
    debugPrint('══════════════════════════════════════════');

    // ── 图像导出引擎测试 ──
    _testImageExport();
  }

  /// 测试多格式图像导出引擎
  Future<void> _testImageExport() async {
    final svc = ResourceService();
    if (!svc.isInitialized || svc.allResources.isEmpty) return;
    final testRes = svc.allResources.first;
    final svgPath = testRes.getSvgPath();

    debugPrint('\n══════════════════════════════════════════');
    debugPrint('🧪 [ImageExportService] 开始测试');

    // 测试 PNG 导出
    final pngResult = await ImageExportService.encodeSvgToBitmap(
      assetPath: svgPath,
      format: 'png',
      targetWidth: 256,
    );
    if (pngResult != null) {
      debugPrint('✅ PNG 导出成功: ${pngResult.length} bytes');
    }

    // 测试 JPEG 导出
    final jpegResult = await ImageExportService.encodeSvgToBitmap(
      assetPath: svgPath,
      format: 'jpeg',
      targetWidth: 256,
    );
    if (jpegResult != null) {
      debugPrint('✅ JPEG 导出成功: ${jpegResult.length} bytes');
    }

    // 测试 WEBP 导出
    final webpResult = await ImageExportService.encodeSvgToBitmap(
      assetPath: svgPath,
      format: 'webp',
      targetWidth: 256,
    );
    if (webpResult != null) {
      debugPrint('✅ WEBP 导出成功: ${webpResult.length} bytes');
    }

    debugPrint('🧪 [ImageExportService] 测试完成');
    debugPrint('══════════════════════════════════════════\n');
  }

  Future<void> _loadAppState() async {
    final accepted = await _disclaimerRepository.hasAccepted();
    final saved = await _genderRepository.getIdentity();
    if (!mounted) return;
    setState(() {
      _disclaimerAccepted = accepted;
      _genderIdentity = saved;
      _isLoading = false;
    });
  }

  Future<void> _loadGreetingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsGreetingName);
    final prefix = prefs.getString(_prefsNamePrefix);
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _greetingName = name;
      if (prefix != null) _namePrefix = prefix;
    });
  }

  Future<void> _saveGreetingName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsGreetingName, name);
    if (!mounted) return;
    setState(() => _greetingName = name);
  }

  Future<void> _saveNamePrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsNamePrefix, prefix);
    if (!mounted) return;
    setState(() => _namePrefix = prefix);
  }

  Future<void> _handleDisclaimerAccepted() async {
    await _disclaimerRepository.setAccepted();
    if (!mounted) return;
    setState(() => _disclaimerAccepted = true);
  }

  Future<void> _handleIdentitySelection(String identity) async {
    await _genderRepository.saveIdentity(identity);
    if (!mounted) return;
    setState(() => _genderIdentity = identity);
  }

  Future<void> _handleIdentityChange(String identity) async {
    await _genderRepository.saveIdentity(identity);
    if (!mounted) return;
    setState(() => _genderIdentity = identity);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingIndicator());
    }

    if (!_disclaimerAccepted) {
      return DisclaimerPage(onAccepted: _handleDisclaimerAccepted);
    }

    if (_genderIdentity == null) {
      return OnboardingScreen(onSelect: _handleIdentitySelection);
    }

    final displayName =
        _namePrefix.isEmpty ? _greetingName : '$_namePrefix. $_greetingName';

    return MainDashboard(
      genderIdentity: _genderIdentity!,
      onIdentityChanged: _handleIdentityChange,
      greetingDisplayName: displayName,
      greetingName: _greetingName,
      namePrefix: _namePrefix,
      onGreetingNameChanged: _saveGreetingName,
      onNamePrefixChanged: _saveNamePrefix,
      themeService: widget.themeService,
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const OnboardingScreen({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF1C1C1A),
                  ]
                : [
                    const Color(0xFFF5A9B8),
                    const Color(0xFFF5A9B8),
                    Colors.white,
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.all_inclusive, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  '欢迎来到跨性别工具箱',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '请选择您的认同方向，我们将为您定制主页展示的内容。此选择仅保存在本地。',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildSelectionButton(
                  context,
                  title: 'MtF (跨性别女性)',
                  subtitle: '展现女性特质 / 获取 MtF 实用指南',
                  icon: Icons.female,
                  color: const Color(0xFFF5A9B8),
                  onTap: () => onSelect(GenderIdentity.mtf),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildSelectionButton(
                  context,
                  title: 'FtM (跨性别男性)',
                  subtitle: '展现男性特质 / 获取 FtM 实用指南',
                  icon: Icons.male,
                  color: const Color(0xFFF5A9B8),
                  onTap: () => onSelect(GenderIdentity.ftm),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildSelectionButton(
                  context,
                  title: 'Non-Binary (非二元性别)',
                  subtitle: '探索多元自我 / 获取通用支持',
                  icon: Icons.transgender,
                  color: Colors.purple,
                  onTap: () => onSelect(GenderIdentity.nb),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF24242C).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.grey.shade500 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  final String genderIdentity;
  final ValueChanged<String> onIdentityChanged;
  final String greetingDisplayName;
  final String greetingName;
  final String namePrefix;
  final ValueChanged<String> onGreetingNameChanged;
  final ValueChanged<String> onNamePrefixChanged;
  final ThemeService themeService;

  const MainDashboard({
    super.key,
    required this.genderIdentity,
    required this.onIdentityChanged,
    required this.greetingDisplayName,
    required this.greetingName,
    required this.namePrefix,
    required this.onGreetingNameChanged,
    required this.onNamePrefixChanged,
    required this.themeService,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  bool _updateChecked = false;

  /// 首页模块可见性状态（true=显示）
  Map<String, bool> _moduleVisibility = {};

  @override
  void initState() {
    super.initState();
    _loadModuleVisibility();
    // 首页渲染完成后静默检测更新
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  /// 从 SharedPreferences 加载模块可见性
  Future<void> _loadModuleVisibility() async {
    final visibility = await HomeModuleVisibility.loadAll();
    if (!mounted) return;
    setState(() => _moduleVisibility = visibility);
  }

  Future<void> _checkForUpdate() async {
    // 防止重复检测
    if (_updateChecked) return;
    _updateChecked = true;

    final result = await UpdateService().checkForUpdate();
    if (!mounted) return;

    if (result.hasUpdate &&
        result.latestVersion != null &&
        result.downloadUrl != null) {
      UpdateDialog.show(
        context,
        version: result.latestVersion!,
        releaseNotes: result.releaseNotes,
        downloadUrl: result.downloadUrl!,
      );
    }
  }

  /// 打开首页模块配置底部抽屉
  ///
  /// 交互流程：
  ///   1. 快照：打开前深拷贝原始配置 → [originalConfig]
  ///   2. 实时预览：拨动开关时直接触发首页 [setState]，背后主界面即时联动
  ///   3. 提交：点击保存 → 持久化到 SharedPreferences → pop(true)
  ///   4. 回滚：下滑/遮罩关闭（未点击保存）→ 恢复 [originalConfig] → 无痕回滚
  Future<void> _showHomeModuleSettings() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    // ── 1. 快照：深拷贝当前配置 ──
    final originalConfig = Map<String, bool>.from(_moduleVisibility);

    // ── 2. 打开 BottomSheet ──
    final saved = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 拖拽指示条 ──
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '首页模块配置',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '选择在首页显示哪些模块',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── 可滚动列表：占据剩余空间，不遮住背后预览 ──
                    Flexible(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: HomeModuleVisibility.allKeys.map((key) {
                          final label =
                              HomeModuleVisibility.moduleLabels[key] ?? key;
                          final icon =
                              HomeModuleVisibility.moduleIcons[key] ?? '';
                          return SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            title: Text(
                              '$icon  $label',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            value: _moduleVisibility[key] ?? true,
                            activeThumbColor: widget.themeService.themeColor,
                            onChanged: (value) {
                              // ── 实时预览：直接更新首页 State ──
                              setState(() {
                                _moduleVisibility[key] = value;
                              });
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── 3. 保存按钮 ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () async {
                            await HomeModuleVisibility.saveAll(
                              _moduleVisibility,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.themeService.themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('保存配置'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // ── 4. 回滚：未保存退出则恢复原始配置 ──
    if (saved != true && mounted) {
      setState(() {
        _moduleVisibility = Map<String, bool>.from(originalConfig);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    final unselectedColor =
        isDark ? const Color(0xFF6B6B76) : const Color(0xFF8A8A86);

    return Scaffold(
      // ── 根据当前 Tab 显示不同的 AppBar ──
      appBar: _buildAppBar(textColor, isDark),
      extendBody: true,
      body: Stack(
        children: [
          // 主内容区（留出底部空间避免被 Pill Bar 遮挡）
          Padding(
            padding: const EdgeInsets.only(bottom: 88),
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // 0: 首页 (Home)
                HomeTab(
                  genderIdentity: widget.genderIdentity,
                  greetingDisplayName: widget.greetingDisplayName,
                  moduleVisibility: _moduleVisibility,
                ),
                // 1: 百科 (Wiki)
                WikiTab(identity: widget.genderIdentity),
                // 2: 工作台 (Workspace)
                WorkspaceTab(genderIdentity: widget.genderIdentity),
                // 3: 我的 (Profile)
                ProfileTab(
                  genderIdentity: widget.genderIdentity,
                  onIdentityChanged: widget.onIdentityChanged,
                  greetingName: widget.greetingName,
                  namePrefix: widget.namePrefix,
                  onGreetingNameChanged: widget.onGreetingNameChanged,
                  onNamePrefixChanged: widget.onNamePrefixChanged,
                  themeService: widget.themeService,
                ),
              ],
            ),
          ),
          // ── 悬浮胶囊导航栏 ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 8,
            left: 16,
            right: 16,
            child: _buildPillNav(isDark, textColor, unselectedColor),
          ),
        ],
      ),
    );
  }

  /// 温润通透悬浮胶囊导航栏 — 去色块，细线图标 + 强调色加粗
  Widget _buildPillNav(bool isDark, Color textColor, Color unselectedColor) {
    // 通透底色：半透明 + 模糊感（无硬边框）
    final bgColor = isDark
        ? const Color(0xFF24242C).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.88);

    // 细线图标（outlined）+ 选中态填充图标
    final destinations = [
      (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '首页'),
      (
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: '资料库'
      ),
      (
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
        label: '工作台'
      ),
      (icon: Icons.person_outline, selectedIcon: Icons.person, label: '我的'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final dest = destinations[index];
              final isSelected = _currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _currentIndex = index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 细线图标 → 选中态填充图标 + 强调色
                      Icon(
                        isSelected ? dest.selectedIcon : dest.icon,
                        size: 22,
                        color: isSelected
                            ? widget.themeService.themeColor
                            : unselectedColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dest.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? widget.themeService.themeColor
                              : unselectedColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// 根据当前 Tab 构建不同的 AppBar
  PreferredSizeWidget _buildAppBar(Color textColor, bool isDark) {
    // Tab 标题配置
    final tabTitles = ['TRANS PRISM', '资料库', '工作台', '我的'];

    return AppBar(
      title: _currentIndex == 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo_in.png', height: 28),
                const SizedBox(width: 8),
                Text(
                  tabTitles[_currentIndex],
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: textColor,
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                tabTitles[_currentIndex],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
      // 首页 AppBar 右侧：模块配置入口（药丸式组合按钮）
      actions: _currentIndex == 0
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: _showHomeModuleSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? widget.themeService.themeColor
                              .withValues(alpha: 0.15)
                          : widget.themeService.themeColor
                              .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.dashboard_customize_rounded,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF7DD9FB)
                              : const Color(0xFF00A2DF),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '自定义',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF7DD9FB)
                                : const Color(0xFF00A2DF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          : null,
    );
  }
}

/// =============================================================================
/// HomeTab — 首页（纯净版）
///
/// 可定制模块：
///   - 问候语（"你好，Mrs. 伙伴"）
///   - HRT 追踪提醒（药物存量 + 血药浓度模拟）
///   - 声音训练辅助
///
/// 用户可通过 AppBar 右侧配置按钮开关各模块的显示。
/// =============================================================================
class HomeTab extends StatelessWidget {
  final String genderIdentity;
  final String greetingDisplayName;
  final Map<String, bool> moduleVisibility;

  const HomeTab({
    super.key,
    required this.genderIdentity,
    required this.greetingDisplayName,
    required this.moduleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);

    // 判断模块可见性
    final showGreeting =
        moduleVisibility[HomeModuleVisibility.keyGreeting] ?? true;
    final showMedStock =
        moduleVisibility[HomeModuleVisibility.keyMedStock] ?? true;
    final showPkSim = moduleVisibility[HomeModuleVisibility.keyPkSim] ?? true;
    final showVoiceTraining =
        moduleVisibility[HomeModuleVisibility.keyVoiceTraining] ?? true;
    final showMedicalDirectory =
        moduleVisibility[HomeModuleVisibility.keyMedicalDirectory] ?? true;
    final showSvgLibrary =
        moduleVisibility[HomeModuleVisibility.keySvgLibrary] ?? true;
    final showImageConverter =
        moduleVisibility[HomeModuleVisibility.keyImageConverter] ?? true;
    final showHormoneConverter =
        moduleVisibility[HomeModuleVisibility.keyHormoneConverter] ?? true;
    final showBraCalculator =
        moduleVisibility[HomeModuleVisibility.keyBraCalculator] ?? true;

    // HRT 标题：只要药物存量或血药浓度任一可见就显示
    final showHrtSection = showMedStock || showPkSim;

    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        // ── 问候区（签名时刻：品牌粉短线 + 标题） ──
        if (showGreeting) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 3,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Text(
            '你好，$greetingDisplayName',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '欢迎回到你的稳态空间',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 36),
        ],

        // ── HRT 追踪提醒 ──
        if (showHrtSection) ...[
          _buildSectionTitle('HRT 追踪', isDark: isDark),
          const SizedBox(height: 12),

          // 药物存量摘要 — 首页核心状态模块，实时显示续航信息
          if (showMedStock) ...[
            const MedicationStockSummary(),
            const SizedBox(height: 12),
          ],

          if (showPkSim)
            _buildPersonalCard(
              context,
              title: '血药浓度模拟',
              subtitle: 'PK 药代动力学测算 · HRT 血药浓度预测',
              icon: Icons.stacked_line_chart_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TrackerScreen(genderIdentity: genderIdentity),
                  ),
                );
              },
            ),
          const SizedBox(height: 28),
        ],

        // ── 工具模块区 ──
        if (showMedicalDirectory ||
            showSvgLibrary ||
            showImageConverter ||
            showHormoneConverter ||
            showBraCalculator) ...[
          _buildSectionTitle('工具箱', isDark: isDark),
          const SizedBox(height: 12),
          if (showMedicalDirectory)
            _buildPersonalCard(
              context,
              title: '友善医疗名录',
              subtitle: '全国跨性别友善医疗机构',
              icon: Icons.local_hospital_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MedicalDirectoryListScreen(),
                  ),
                );
              },
            ),
          if (showMedicalDirectory &&
              (showSvgLibrary || showImageConverter || showHormoneConverter))
            const SizedBox(height: 12),
          if (showSvgLibrary)
            _buildPersonalCard(
              context,
              title: '图解资源 (SVG库)',
              subtitle: '浏览与导出跨性别主题 SVG 图标',
              icon: Icons.photo_library_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SvgResourceGalleryScreen(),
                  ),
                );
              },
            ),
          if (showSvgLibrary && (showImageConverter || showHormoneConverter))
            const SizedBox(height: 12),
          if (showImageConverter)
            _buildPersonalCard(
              context,
              title: '图片格式转换',
              subtitle: 'SVG/位图格式互转·分辨率调整',
              icon: Icons.swap_horiz_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImageConverterScreen(),
                  ),
                );
              },
            ),
          if (showImageConverter && showHormoneConverter)
            const SizedBox(height: 12),
          if (showHormoneConverter)
            _buildPersonalCard(
              context,
              title: '激素换算器',
              subtitle: 'E2/T/PRL 等单位实时双向换算',
              icon: Icons.balance_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HormoneConverterScreen(),
                  ),
                );
              },
            ),
          if ((showImageConverter || showHormoneConverter) && showBraCalculator)
            const SizedBox(height: 12),
          if (showBraCalculator)
            _buildPersonalCard(
              context,
              title: '罩杯计算器',
              subtitle: '基于 MtF.wiki 算法 · 发育记录追踪',
              icon: Icons.straighten_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BraCalculatorPage(),
                  ),
                );
              },
            ),
          const SizedBox(height: 28),
        ],

        // ── 声音训练辅助 ──
        if (showVoiceTraining) ...[
          _buildSectionTitle('声音训练', isDark: isDark),
          const SizedBox(height: 12),
          _buildPersonalCard(
            context,
            title: '声音训练辅助',
            subtitle: '基于 VFS Tracker 的嗓音训练工具集',
            icon: Icons.mic_external_on_rounded,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VoiceTrainingHomeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
        ],

        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF98989E) : const Color(0xFF8E8E93),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildPersonalCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final secondaryColor =
        isDark ? const Color(0xFF8E8E96) : const Color(0xFF8A8A86);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF24242C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.035),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // 单色克制图标（跟随主题）
            Icon(icon, size: 24, color: secondaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: isDark
                          ? const Color(0xFFEDEDF0)
                          : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: secondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: secondaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final String genderIdentity;
  final ValueChanged<String> onIdentityChanged;
  final String greetingName;
  final String namePrefix;
  final ValueChanged<String> onGreetingNameChanged;
  final ValueChanged<String> onNamePrefixChanged;
  final ThemeService themeService;

  const ProfileTab({
    super.key,
    required this.genderIdentity,
    required this.onIdentityChanged,
    required this.greetingName,
    required this.namePrefix,
    required this.onGreetingNameChanged,
    required this.onNamePrefixChanged,
    required this.themeService,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController _greetingController;

  bool _customPrefix = false;
  late TextEditingController _customPrefixController;

  static const _prefixOptions = {
    '': '不显示',
    'Mr': 'Mr.',
    'Ms': 'Ms.',
    'Mrs': 'Mrs.',
    'Miss': 'Miss.',
    'Mx': 'Mx.',
    'Dr': 'Dr.',
    '__custom__': '自定义...',
  };

  @override
  void initState() {
    super.initState();
    _greetingController = TextEditingController(text: widget.greetingName);
    _customPrefix = !_prefixOptions.containsKey(widget.namePrefix) &&
        widget.namePrefix.isNotEmpty;
    _customPrefixController = TextEditingController(
      text: _customPrefix ? widget.namePrefix : '',
    );
  }

  @override
  void didUpdateWidget(ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.greetingName != oldWidget.greetingName) {
      _greetingController.text = widget.greetingName;
    }
  }

  @override
  void dispose() {
    _greetingController.dispose();
    _customPrefixController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckUpdate(BuildContext context) async {
    // 显示检测中的提示
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在检查更新...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await UpdateService().checkForUpdate();

    if (!context.mounted) return;

    // 隐藏当前 SnackBar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.hasUpdate &&
        result.latestVersion != null &&
        result.downloadUrl != null) {
      // 情况 1：检测到新版本 → 弹出更新 Dialog
      UpdateDialog.show(
        context,
        version: result.latestVersion!,
        releaseNotes: result.releaseNotes,
        downloadUrl: result.downloadUrl!,
      );
    } else if (result.networkError) {
      // 情况 2：网络连接失败 → 提醒用户检查网络
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('网络连接失败，请检查网络后重试'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE57373),
        ),
      );
    } else {
      // 情况 3：已是最新版本
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已是最新版本 🎉'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333);
    final themeService = widget.themeService;
    final secondaryTextColor =
        isDark ? const Color(0xFF98989E) : const Color(0xFF8A8A86);
    final cardBorderColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final cardBg = isDark ? const Color(0xFF1C1C1A) : Colors.white;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        // ═══════════════════════════════════════════════
        //   身份与资料
        // ═══════════════════════════════════════════════
        _buildSectionHeader('身份与资料', isDark: isDark),
        _buildGroupContainer(
          isDark: isDark,
          cardBg: cardBg,
          cardBorderColor: cardBorderColor,
          children: [
            // ── 性别认同 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.transgender,
              leadingColor: themeService.themeColor,
              title: '性别认同',
              subtitle: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    GenderIdentity.label(widget.genderIdentity),
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ],
              ),
              onTap: () => _showGenderBottomSheet(context),
            ),
            _buildDivider(isDark: isDark),
            // ── 个人称呼 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.badge_outlined,
              leadingColor: themeService.themeColor,
              title: '个人称呼',
              subtitle: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.namePrefix.isNotEmpty ? '${widget.namePrefix} ' : ''}${widget.greetingName.isNotEmpty ? widget.greetingName : '伙伴'}',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ],
              ),
              onTap: () => _showGreetingBottomSheet(
                  context, textColor, secondaryTextColor),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        //   外观与显示
        // ═══════════════════════════════════════════════
        _buildSectionHeader('外观与显示', isDark: isDark),
        _buildGroupContainer(
          isDark: isDark,
          cardBg: cardBg,
          cardBorderColor: cardBorderColor,
          children: [
            // ── 主题模式 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: _themeModeIcon(widget.themeService.themeMode),
              leadingColor: themeService.themeColor,
              title: '主题模式',
              subtitle: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _themeModeName(widget.themeService.themeMode),
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ],
              ),
              onTap: () => _showThemeBottomSheet(context),
            ),
            _buildDivider(isDark: isDark),
            // ── 主题色 ──
            ListenableBuilder(
              listenable: themeService,
              builder: (context, _) {
                return _buildSettingsTile(
                  isDark: isDark,
                  leadingIcon: Icons.palette_outlined,
                  leadingColor: themeService.themeColor,
                  title: '主题色',
                  subtitle: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniColorDot(
                        context,
                        color: const Color(0xFFF5A9B8),
                        isSelected: themeService.themeColor.toARGB32() ==
                            const Color(0xFFF5A9B8).toARGB32(),
                        onTap: () =>
                            themeService.setThemeColor(const Color(0xFFF5A9B8)),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniColorDot(
                        context,
                        color: const Color(0xFF5BCEFA),
                        isSelected: themeService.themeColor.toARGB32() ==
                            const Color(0xFF5BCEFA).toARGB32(),
                        onTap: () =>
                            themeService.setThemeColor(const Color(0xFF5BCEFA)),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniColorDot(
                        context,
                        color: const Color(0xFFD97757),
                        isSelected: themeService.themeColor.toARGB32() ==
                            const Color(0xFFD97757).toARGB32(),
                        onTap: () =>
                            themeService.setThemeColor(const Color(0xFFD97757)),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  onTap: () {}, // 点击点阵直接切换颜色，无需整体点击
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        //   高级与系统
        // ═══════════════════════════════════════════════
        _buildSectionHeader('高级与系统', isDark: isDark),
        _buildGroupContainer(
          isDark: isDark,
          cardBg: cardBg,
          cardBorderColor: cardBorderColor,
          children: [
            // ── 通知与提醒权限入口 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.notifications_active_outlined,
              leadingColor: themeService.themeColor,
              title: '通知权限与保活',
              subtitle: null,
              onTap: () => _showBatteryOptimizationDialog(context),
            ),
            _buildDivider(isDark: isDark),
            // ── 数据管理入口 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.sd_storage_outlined,
              leadingColor: themeService.themeColor,
              title: '数据导出与恢复',
              subtitle: null,
              onTap: () =>
                  _showDataManagementBottomSheet(context, isDark, themeService),
            ),
            _buildDivider(isDark: isDark),
            // ── 关于与支持入口 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.info_outline,
              leadingColor: themeService.themeColor,
              title: '关于与支持',
              subtitle: null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── 版本号 + 版权信息 ──
        _buildVersionFooter(isDark: isDark),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  分组标题
  // ════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF6B6B76) : const Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  分组容器（一张大卡片包多个 ListTile）
  // ════════════════════════════════════════════════════════════

  Widget _buildGroupContainer({
    required bool isDark,
    required Color cardBg,
    required Color cardBorderColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorderColor),
      ),
      color: cardBg,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  通用设置列表项
  // ════════════════════════════════════════════════════════════

  Widget _buildSettingsTile({
    required bool isDark,
    required IconData leadingIcon,
    required Color leadingColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF24242C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: GradientIcon(leadingIcon, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFEDEDF0) : const Color(0xFF333333),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF98989E) : const Color(0xFF8A8A86),
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            size: 20,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: const RoundedRectangleBorder(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  分隔线
  // ════════════════════════════════════════════════════════════

  Widget _buildDivider({required bool isDark}) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  个人称呼内嵌编辑区
  // ════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════
  //  个人称呼 BottomSheet
  // ════════════════════════════════════════════════════════════

  void _showGreetingBottomSheet(
    BuildContext context,
    Color textColor,
    Color secondaryTextColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '设置个人称呼',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFEDEDF0)
                              : const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '设置首页问候语中显示的称呼和名字前缀',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF98989E)
                              : const Color(0xFF8A8A86),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 前缀下拉
                      DropdownButtonFormField<String>(
                        initialValue:
                            _prefixOptions.containsKey(widget.namePrefix)
                                ? widget.namePrefix
                                : '__custom__',
                        decoration: InputDecoration(
                          labelText: '前缀',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF24242C)
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _prefixOptions.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          if (v == '__custom__') {
                            setModalState(() => _customPrefix = true);
                          } else {
                            setModalState(() => _customPrefix = false);
                            widget.onNamePrefixChanged(v);
                          }
                        },
                      ),
                      if (_customPrefix) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customPrefixController,
                          decoration: InputDecoration(
                            labelText: '自定义前缀',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF24242C)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) {
                            if (v.isNotEmpty) widget.onNamePrefixChanged(v);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _greetingController,
                        decoration: InputDecoration(
                          labelText: '称呼（默认"伙伴"）',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF24242C)
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty) widget.onGreetingNameChanged(v);
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.themeService.themeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '完成',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniColorDot(
    BuildContext context, {
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  性别认同 BottomSheet
  // ════════════════════════════════════════════════════════════

  void _showGenderBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '选择性别认同',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFEDEDF0)
                        : const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '修改后将立即更新首页推荐内容',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF98989E)
                        : const Color(0xFF8A8A86),
                  ),
                ),
                const SizedBox(height: 20),
                ...GenderIdentity.values.map((id) {
                  final selected = id == widget.genderIdentity;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: selected
                            ? BorderSide(
                                color: widget.themeService.themeColor,
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                      tileColor: selected
                          ? widget.themeService.themeColor
                              .withValues(alpha: 0.06)
                          : (isDark
                              ? const Color(0xFF24242C)
                              : Colors.grey.shade50),
                      leading: Icon(
                        id == GenderIdentity.mtf
                            ? Icons.female
                            : id == GenderIdentity.ftm
                                ? Icons.male
                                : Icons.transgender,
                        color: selected
                            ? widget.themeService.themeColor
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500),
                      ),
                      title: Text(
                        GenderIdentity.label(id),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? widget.themeService.themeColor
                              : (isDark
                                  ? const Color(0xFFEDEDF0)
                                  : const Color(0xFF333333)),
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: widget.themeService.themeColor,
                              size: 22,
                            )
                          : null,
                      onTap: () {
                        widget.onIdentityChanged(id);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  主题模式 BottomSheet
  // ════════════════════════════════════════════════════════════

  void _showThemeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '选择主题模式',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFEDEDF0)
                        : const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                _buildThemeOption(
                  ctx: ctx,
                  mode: ThemeMode.light,
                  icon: Icons.light_mode,
                  iconColor: Colors.amber.shade600,
                  label: '浅色模式',
                  desc: '始终使用浅色外观',
                  selected: widget.themeService.themeMode == ThemeMode.light,
                ),
                const SizedBox(height: 8),
                _buildThemeOption(
                  ctx: ctx,
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode,
                  iconColor: widget.themeService.themeColor,
                  label: '深色模式',
                  desc: '始终使用深色外观',
                  selected: widget.themeService.themeMode == ThemeMode.dark,
                ),
                const SizedBox(height: 8),
                _buildThemeOption(
                  ctx: ctx,
                  mode: ThemeMode.system,
                  icon: Icons.settings_brightness,
                  iconColor: const Color(0xFF8E8E93),
                  label: '跟随系统',
                  desc: isDark ? '当前跟随系统 → 深色' : '当前跟随系统 → 浅色',
                  selected: widget.themeService.themeMode == ThemeMode.system,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext ctx,
    required ThemeMode mode,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String desc,
    required bool selected,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: widget.themeService.themeColor, width: 1.5)
            : BorderSide.none,
      ),
      tileColor: selected
          ? widget.themeService.themeColor.withValues(alpha: 0.06)
          : null,
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        desc,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: selected
          ? Icon(Icons.check_circle,
              color: widget.themeService.themeColor, size: 22)
          : null,
      onTap: () {
        widget.themeService.setThemeMode(mode);
        Navigator.pop(ctx);
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  主题模式辅助
  // ════════════════════════════════════════════════════════════

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.settings_brightness;
    }
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  String _themeModeLabel(ThemeMode mode, bool isDark) {
    switch (mode) {
      case ThemeMode.light:
        return '始终使用浅色外观';
      case ThemeMode.dark:
        return '始终使用深色外观';
      case ThemeMode.system:
        return isDark ? '当前 → 深色' : '当前 → 浅色';
    }
  }

  // ════════════════════════════════════════════════════════════
  //  版本页脚
  // ════════════════════════════════════════════════════════════

  Widget _buildVersionFooter({required bool isDark}) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '?.?.?';
        return Column(
          children: [
            Text(
              '当前版本 v$version',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  通知到达率优化 Dialog
  // ════════════════════════════════════════════════════════════

  void _showBatteryOptimizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: const SingleChildScrollView(
              child: BatteryOptimizationGuideCard(),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  数据导出与恢复 BottomSheet
  // ════════════════════════════════════════════════════════════

  void _showDataManagementBottomSheet(
    BuildContext context,
    bool isDark,
    ThemeService themeService,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '数据管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFEDEDF0)
                        : const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.backup_rounded,
                      color: themeService.themeColor),
                  title: const Text('导出数据（迁移专用）',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('导出所有本地数据为 JSON 备份文件'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleExportData(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.unarchive_rounded,
                      color: themeService.themeColor),
                  title: const Text('导入数据',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('从备份 JSON 文件恢复数据到本机'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleImportData(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  数据导出（迁移原有内联逻辑）
  // ════════════════════════════════════════════════════════════

  Future<void> _handleExportData(BuildContext context) async {
    // 弹出 PK 血药浓度提示对话框
    final acknowledged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFE57373)),
            SizedBox(width: 8),
            Text('备份提示'),
          ],
        ),
        content: const Text('PK 血药浓度模拟数据请在血药浓度板块内的设置进行单独导出，当前备份操作不包含血药浓度模拟数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('我已知晓'),
          ),
        ],
      ),
    );
    if (acknowledged != true) return;
    if (!context.mounted) return;

    // 后台静默初始化 PK 模拟，确保 Oyama 数据可导出
    if (!DataMigrationService.hasOyamaController) {
      await TrackerScreen.ensureBackgroundInitialized();
    }
    final success = await DataMigrationService.exportData();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 数据已成功导出，请妥善保管备份文件'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出已取消或未找到可导出数据'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  数据导入（迁移原有内联逻辑）
  // ════════════════════════════════════════════════════════════

  Future<void> _handleImportData(BuildContext context) async {
    // 后台静默初始化 PK 模拟，确保 Oyama 数据可导入
    if (!DataMigrationService.hasOyamaController) {
      await TrackerScreen.ensureBackgroundInitialized();
    }
    final success = await DataMigrationService.importData();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 数据已成功导入，建议重启 App 以完全生效'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导入已取消或文件格式不正确'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
