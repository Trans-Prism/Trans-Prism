import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'models/gender_identity.dart';
import 'screens/about_screen.dart';
import 'screens/disclaimer_page.dart';
import 'screens/disclaimer_view_screen.dart';
import 'screens/hormone_converter_screen.dart';
import 'screens/image_converter_screen.dart';
import 'screens/medical_directory/medical_directory_list_screen.dart';
import 'screens/pk_simulation_screen.dart';
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

/// 构建亮色主题
ThemeData _buildLightTheme() {
  return ThemeData(
    scaffoldBackgroundColor: const Color(0xFFFAFAFC),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5BCEFA),
      primary: const Color(0xFF5BCEFA),
      secondary: const Color(0xFFF5A9B8),
      surface: const Color(0xFFFAFAFC),
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFF1D1D1F),
        fontSize: 20,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5BCEFA),
          );
        }
        return const TextStyle(
          fontSize: 11,
          color: Color(0xFF86868B),
        );
      }),
    ),
    useMaterial3: true,
  );
}

/// 构建暗色主题
ThemeData _buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F0F12),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5BCEFA),
      primary: const Color(0xFF5BCEFA),
      secondary: const Color(0xFFF5A9B8),
      surface: const Color(0xFF1C1C1E),
      brightness: Brightness.dark,
    ),
    // ── 文字主题 ──
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Color(0xFFF5F5F7)),
      titleMedium: TextStyle(color: Color(0xFFF5F5F7)),
      titleSmall: TextStyle(color: Color(0xFFF5F5F7)),
      bodyLarge: TextStyle(color: Color(0xFFF5F5F7)),
      bodyMedium: TextStyle(color: Color(0xFFF5F5F7)),
      bodySmall: TextStyle(color: Color(0xFFAEAEB2)),
      labelLarge: TextStyle(color: Color(0xFFF5F5F7)),
      labelMedium: TextStyle(color: Color(0xFFAEAEB2)),
      labelSmall: TextStyle(color: Color(0xFF636366)),
    ),
    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: Color(0xFFF5F5F7),
        fontSize: 20,
      ),
      iconTheme: IconThemeData(color: Color(0xFFAEAEB2)),
      actionsIconTheme: IconThemeData(color: Color(0xFFAEAEB2)),
    ),
    // ── 图标主题 ──
    iconTheme: const IconThemeData(color: Color(0xFFAEAEB2)),
    primaryIconTheme: const IconThemeData(color: Color(0xFF5BCEFA)),
    // ── 卡片 ──
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3A3A3C)),
      ),
      color: const Color(0xFF1C1C1E),
    ),
    // ── 底部导航栏 ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1C1C1E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5BCEFA),
          );
        }
        return const TextStyle(
          fontSize: 11,
          color: Color(0xFF636366),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF5BCEFA));
        }
        return const IconThemeData(color: Color(0xFF636366));
      }),
    ),
    // ── 底部应用栏 ──
    bottomAppBarTheme: const BottomAppBarTheme(
      color: Color(0xFF1C1C1E),
    ),
    // ── 对话框 ──
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF5F5F7),
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFFAEAEB2),
      ),
    ),
    // ── 输入框 ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5BCEFA)),
      ),
      labelStyle: const TextStyle(color: Color(0xFFAEAEB2)),
      hintStyle: const TextStyle(color: Color(0xFF636366)),
    ),
    // ── 下拉菜单 ──
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
        ),
      ),
    ),
    // ── 弹出菜单 ──
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(color: Color(0xFFF5F5F7), fontSize: 14),
    ),
    // ── 菜单按钮 ──
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF2C2C2E)),
      ),
    ),
    // ── 开关 ──
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF5BCEFA);
        }
        return Colors.grey.shade500;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF5BCEFA).withOpacity(0.3);
        }
        return const Color(0xFF3A3A3C);
      }),
    ),
    // ── Chip ──
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2C2C2E),
      labelStyle: const TextStyle(color: Color(0xFFF5F5F7)),
      secondaryLabelStyle: const TextStyle(color: Color(0xFFAEAEB2)),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    // ── 按钮 ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: const Color(0xFFF5F5F7),
        backgroundColor: const Color(0xFF5BCEFA),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF5BCEFA),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF5BCEFA),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF5F5F7),
        side: const BorderSide(color: Color(0xFF3A3A3C)),
      ),
    ),
    // ── 复选框、单选按钮 ──
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all(Colors.white),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF5BCEFA);
        }
        return const Color(0xFF3A3A3C);
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF5BCEFA);
        }
        return const Color(0xFFAEAEB2);
      }),
    ),
    // ── 进度条 ──
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF5BCEFA),
      circularTrackColor: Color(0xFF3A3A3C),
      linearTrackColor: Color(0xFF3A3A3C),
    ),
    // ── 分隔线 ──
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3A3A3C),
      space: 1,
    ),
    // ── 时间选择器、日期选择器 ──
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xFF2C2C2E),
      headerBackgroundColor: const Color(0xFF1C1C1E),
      headerForegroundColor: const Color(0xFFF5F5F7),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return const Color(0xFFF5F5F7);
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF5BCEFA);
        }
        return null;
      }),
      todayForegroundColor: WidgetStateProperty.all(const Color(0xFF5BCEFA)),
      surfaceTintColor: Colors.transparent,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: Color(0xFF2C2C2E),
      hourMinuteColor: Color(0xFF1C1C1E),
      hourMinuteTextColor: Color(0xFFF5F5F7),
      dayPeriodTextColor: Color(0xFFF5F5F7),
      dialHandColor: Color(0xFF5BCEFA),
      dialBackgroundColor: Color(0xFF1C1C1E),
      dialTextColor: Color(0xFFF5F5F7),
      entryModeIconColor: Color(0xFF5BCEFA),
    ),
    // ── 提示框 ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2C2C2E),
      contentTextStyle: const TextStyle(color: Color(0xFFF5F5F7)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    // ── 工具提示 ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Color(0xFFF5F5F7), fontSize: 12),
    ),
    // ── BottomSheet ──
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1C1C1E),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    // ── TabBar ──
    tabBarTheme: const TabBarTheme(
      labelColor: Color(0xFF5BCEFA),
      unselectedLabelColor: Color(0xFF636366),
      indicatorColor: Color(0xFF5BCEFA),
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
          title: 'Project Trans Toolbox',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
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
    final transSym = svc.searchResources('trans symbol').first;
    debugPrint(
        '📁 trans_symbol twemoji path: ${transSym.getSvgPath(preferredStyle: "twemoji")}');
    debugPrint(
        '📁 trans_symbol openmoji fallback: ${transSym.getSvgPath(preferredStyle: "openmoji")}');

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
      return const Scaffold(
        body: LoadingIndicator(),
      );
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
                    const Color(0xFF0F0F12),
                  ]
                : [
                    const Color(0xFF5BCEFA),
                    const Color(0xFFF5A9B8),
                    Colors.white
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
                  color: const Color(0xFF5BCEFA),
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
              ? const Color(0xFF2C2C2E).withOpacity(0.9)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey),
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

    if (result.hasUpdate && result.latestVersion != null) {
      UpdateDialog.show(
        context,
        version: result.latestVersion!,
        releaseNotes: result.releaseNotes,
        apkDownloadUrls: result.apkDownloadUrls,
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
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

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
                                horizontal: 16, vertical: 2),
                            title: Text(
                              '$icon  $label',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            value: _moduleVisibility[key] ?? true,
                            activeColor: const Color(0xFF5BCEFA),
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
                                _moduleVisibility);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5BCEFA),
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
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

    return Scaffold(
      // ── 根据当前 Tab 显示不同的 AppBar ──
      appBar: _buildAppBar(textColor, isDark),
      body: IndexedStack(
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined,
                  color: isDark
                      ? const Color(0xFF636366)
                      : const Color(0xFFC7C7CC)),
              selectedIcon: const Icon(Icons.home, color: Color(0xFF5BCEFA)),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined,
                  color: isDark
                      ? const Color(0xFF636366)
                      : const Color(0xFFC7C7CC)),
              selectedIcon:
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF5BCEFA)),
              label: '百科',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined,
                  color: isDark
                      ? const Color(0xFF636366)
                      : const Color(0xFFC7C7CC)),
              selectedIcon:
                  const Icon(Icons.grid_view_rounded, color: Color(0xFF5BCEFA)),
              label: '工作台',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline,
                  color: isDark
                      ? const Color(0xFF636366)
                      : const Color(0xFFC7C7CC)),
              selectedIcon:
                  const Icon(Icons.person_rounded, color: Color(0xFF5BCEFA)),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  /// 根据当前 Tab 构建不同的 AppBar
  PreferredSizeWidget _buildAppBar(Color textColor, bool isDark) {
    // Tab 标题配置
    final tabTitles = ['TRANS PRISM', '百科', '工作台', '我的'];

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
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: _showHomeModuleSettings,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFF5BCEFA).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.dashboard_customize_rounded,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF98989E)
                              : const Color(0xFF5BCEFA),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '自定义',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF98989E)
                                : const Color(0xFF5BCEFA),
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
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);

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

    // HRT 标题：只要药物存量或血药浓度任一可见就显示
    final showHrtSection = showMedStock || showPkSim;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        // ── 问候区 ──
        if (showGreeting) ...[
          Text(
            '你好，$greetingDisplayName 👋',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '欢迎回到你的稳态空间',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 28),
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
                        PKSimulationScreen(genderIdentity: genderIdentity),
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
            showHormoneConverter) ...[
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 统一渐变图标（品牌色浅蓝→粉紫）
            GradientIcon(icon, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFF5F5F7)
                          : const Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF98989E)
                          : const Color(0xFF999999),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              size: 22,
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
    _customPrefixController =
        TextEditingController(text: _customPrefix ? widget.namePrefix : '');
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

    if (result.hasUpdate && result.latestVersion != null) {
      // 情况 1：检测到新版本 → 弹出更新 Dialog
      UpdateDialog.show(
        context,
        version: result.latestVersion!,
        releaseNotes: result.releaseNotes,
        apkDownloadUrls: result.apkDownloadUrls,
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
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final secondaryTextColor =
        isDark ? const Color(0xFF98989E) : const Color(0xFF86868B);
    final cardBorderColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        // ═══════════════════════════════════════════════
        //   个性化与身份
        // ═══════════════════════════════════════════════
        _buildSectionHeader('个性化与身份', isDark: isDark),
        _buildGroupContainer(
          isDark: isDark,
          cardBg: cardBg,
          cardBorderColor: cardBorderColor,
          children: [
            // ── 性别认同 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.transgender,
              leadingColor: const Color(0xFF5BCEFA),
              title: '性别认同',
              subtitle: GenderIdentity.label(widget.genderIdentity),
              onTap: () => _showGenderBottomSheet(context),
            ),
            _buildDivider(isDark: isDark),
            // ── 个人称呼（内嵌表单） ──
            _buildGreetingSection(
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            _buildDivider(isDark: isDark),
            // ── 主题模式 ──
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: _themeModeIcon(widget.themeService.themeMode),
              leadingColor: const Color(0xFF5BCEFA),
              title: '主题模式',
              subtitle: _themeModeLabel(widget.themeService.themeMode, isDark),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _themeModeName(widget.themeService.themeMode),
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18,
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ],
              ),
              onTap: () => _showThemeBottomSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        //   系统与提醒
        // ═══════════════════════════════════════════════
        _buildSectionHeader('系统与提醒', isDark: isDark),
        const BatteryOptimizationGuideCard(),
        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        //   数据与备份
        // ═══════════════════════════════════════════════
        _buildSectionHeader('数据与备份', isDark: isDark),
        _buildGroupContainer(
          isDark: isDark,
          cardBg: cardBg,
          cardBorderColor: cardBorderColor,
          children: [
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.backup_rounded,
              leadingColor: const Color(0xFF5BCEFA),
              title: '旧版数据导出（迁移专用）',
              subtitle: '导出所有本地数据为 JSON 备份文件',
              onTap: () => _handleExportData(context),
            ),
            _buildDivider(isDark: isDark),
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.unarchive_rounded,
              leadingColor: const Color(0xFF5BCEFA),
              title: '新版数据导入',
              subtitle: '从备份 JSON 文件恢复数据到本机',
              onTap: () => _handleImportData(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════
        //   关于与支持
        // ═══════════════════════════════════════════════
        _buildSectionHeader('关于与支持', isDark: isDark),
        _buildGroupContainer(
          isDark: isDark,
          cardBg: cardBg,
          cardBorderColor: cardBorderColor,
          children: [
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.info_outline,
              leadingColor: const Color(0xFF5BCEFA),
              title: '关于',
              subtitle: '应用信息与第三方开源许可',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
            ),
            _buildDivider(isDark: isDark),
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.system_update_rounded,
              leadingColor: const Color(0xFF5BCEFA),
              title: '检查更新',
              subtitle: '手动检测是否有新版本可用',
              onTap: () => _handleCheckUpdate(context),
            ),
            _buildDivider(isDark: isDark),
            _buildSettingsTile(
              isDark: isDark,
              leadingIcon: Icons.description_outlined,
              leadingColor: const Color(0xFF5BCEFA),
              title: '免责声明',
              subtitle: '医疗、数据与开源许可声明',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DisclaimerViewScreen(),
                  ),
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
          color: isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93),
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
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: leadingColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(leadingIcon, color: leadingColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF98989E) : const Color(0xFF86868B),
        ),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right,
              size: 20,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
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

  Widget _buildGreetingSection({
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '个人称呼',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '设置首页问候语中显示的称呼和名字前缀',
            style: TextStyle(fontSize: 12, color: secondaryTextColor),
          ),
          const SizedBox(height: 12),
          // 前缀 + 昵称行
          Row(
            children: [
              // 前缀下拉
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  value: _prefixOptions.containsKey(widget.namePrefix)
                      ? widget.namePrefix
                      : '__custom__',
                  decoration: InputDecoration(
                    labelText: '前缀',
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  items: _prefixOptions.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    if (v == '__custom__') {
                      setState(() => _customPrefix = true);
                    } else {
                      setState(() => _customPrefix = false);
                      widget.onNamePrefixChanged(v);
                    }
                  },
                ),
              ),
              if (_customPrefix) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _customPrefixController,
                    decoration: InputDecoration(
                      labelText: '自定义',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) widget.onNamePrefixChanged(v);
                    },
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // 昵称
              Expanded(
                child: TextField(
                  controller: _greetingController,
                  decoration: InputDecoration(
                    labelText: '称呼（默认"伙伴"）',
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty) widget.onGreetingNameChanged(v);
                  },
                ),
              ),
            ],
          ),
        ],
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
                        ? const Color(0xFFF5F5F7)
                        : const Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '修改后将立即更新首页推荐内容',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF98989E)
                        : const Color(0xFF86868B),
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
                            ? const BorderSide(
                                color: Color(0xFF5BCEFA), width: 1.5)
                            : BorderSide.none,
                      ),
                      tileColor: selected
                          ? const Color(0xFF5BCEFA).withOpacity(0.06)
                          : (isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey.shade50),
                      leading: Icon(
                        id == GenderIdentity.mtf
                            ? Icons.female
                            : id == GenderIdentity.ftm
                                ? Icons.male
                                : Icons.transgender,
                        color: selected
                            ? const Color(0xFF5BCEFA)
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
                              ? const Color(0xFF5BCEFA)
                              : (isDark
                                  ? const Color(0xFFF5F5F7)
                                  : const Color(0xFF1D1D1F)),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF5BCEFA), size: 22)
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
                        ? const Color(0xFFF5F5F7)
                        : const Color(0xFF1D1D1F),
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
                  iconColor: const Color(0xFF5BCEFA),
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
            ? const BorderSide(color: Color(0xFF5BCEFA), width: 1.5)
            : BorderSide.none,
      ),
      tileColor: selected ? const Color(0xFF5BCEFA).withOpacity(0.06) : null,
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
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF5BCEFA), size: 22)
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
  //  数据导出（迁移原有内联逻辑）
  // ════════════════════════════════════════════════════════════

  Future<void> _handleExportData(BuildContext context) async {
    // 弹出 PK 血药浓度提示对话框
    final acknowledged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFE57373)),
            SizedBox(width: 8),
            Text('备份提示'),
          ],
        ),
        content: const Text(
          'PK 血药浓度模拟数据请在血药浓度板块内的设置进行单独导出，当前备份操作不包含血药浓度模拟数据。',
        ),
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
      await PKSimulationScreen.ensureBackgroundInitialized();
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
      await PKSimulationScreen.ensureBackgroundInitialized();
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
