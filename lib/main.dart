import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'models/gender_identity.dart';
import 'models/wiki_config.dart';
import 'screens/about_screen.dart';
import 'screens/disclaimer_page.dart';
import 'screens/disclaimer_view_screen.dart';
import 'screens/hormone_converter_screen.dart';
import 'screens/medical_directory/medical_directory_list_screen.dart';
import 'screens/offline_wiki_screen.dart';
import 'screens/wiki_web_screen.dart';
import 'services/wiki_offline_service.dart';
import 'services/wiki_update_manager.dart';
import 'screens/pk_simulation_screen.dart';
import 'screens/inventory_dashboard_screen.dart';
import 'screens/voice_training/voice_training_home.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'services/wiki_sync_service.dart';
import 'widgets/update_dialog.dart';
import 'widgets/wiki_license_notice.dart';
import 'widgets/loading_indicator.dart';
import 'storage/disclaimer_repository.dart';
import 'storage/gender_identity_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const TransToolboxApp());
}

class TransToolboxApp extends StatelessWidget {
  const TransToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Trans Toolbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAFAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BCEFA),
          primary: const Color(0xFF5BCEFA),
          secondary: const Color(0xFFF5A9B8),
          surface: const Color(0xFFFAFAFC),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
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
      ),
      home: const AppRootController(),
    );
  }
}

class AppRootController extends StatefulWidget {
  const AppRootController({super.key});

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
  }

  Future<void> _initNotifications() async {
    await NotificationService().initialize();
    await NotificationService().requestPermission();
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
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const OnboardingScreen({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5BCEFA), Color(0xFFF5A9B8), Colors.white],
            stops: [0.0, 0.5, 1.0],
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
                const Text(
                  '欢迎来到跨性别工具箱',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  '请选择您的认同方向，我们将为您定制主页展示的内容。此选择仅保存在本地。',
                  style: TextStyle(fontSize: 15, color: Colors.black54),
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
                ),
                const SizedBox(height: 16),
                _buildSelectionButton(
                  context,
                  title: 'FtM (跨性别男性)',
                  subtitle: '展现男性特质 / 获取 FtM 实用指南',
                  icon: Icons.male,
                  color: const Color(0xFF5BCEFA),
                  onTap: () => onSelect(GenderIdentity.ftm),
                ),
                const SizedBox(height: 16),
                _buildSelectionButton(
                  context,
                  title: 'Non-Binary (非二元性别)',
                  subtitle: '探索多元自我 / 获取通用支持',
                  icon: Icons.transgender,
                  color: Colors.purple,
                  onTap: () => onSelect(GenderIdentity.nb),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
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
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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

  const MainDashboard({
    super.key,
    required this.genderIdentity,
    required this.onIdentityChanged,
    required this.greetingDisplayName,
    required this.greetingName,
    required this.namePrefix,
    required this.onGreetingNameChanged,
    required this.onNamePrefixChanged,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    // 首页渲染完成后静默检测更新
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _currentIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo_in.png', height: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'TRANS PRISM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ],
              )
            : const Text(
                '用户',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D1D1F),
                ),
              ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(
              genderIdentity: widget.genderIdentity,
              greetingDisplayName: widget.greetingDisplayName),
          UserTab(
            genderIdentity: widget.genderIdentity,
            onIdentityChanged: widget.onIdentityChanged,
            greetingName: widget.greetingName,
            namePrefix: widget.namePrefix,
            onGreetingNameChanged: widget.onGreetingNameChanged,
            onNamePrefixChanged: widget.onNamePrefixChanged,
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
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined, color: Color(0xFFC7C7CC)),
              selectedIcon: const Icon(Icons.home, color: Color(0xFF5BCEFA)),
              label: '首页',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline, color: Color(0xFFC7C7CC)),
              selectedIcon: const Icon(Icons.person, color: Color(0xFF5BCEFA)),
              label: '用户',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final String genderIdentity;
  final String greetingDisplayName;

  const HomeTab(
      {super.key,
      required this.genderIdentity,
      required this.greetingDisplayName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '你好，$greetingDisplayName 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '欢迎回到你的稳态空间',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
              children: _buildFilteredFeatures(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredFeatures(BuildContext context) {
    return [
      _buildMenuCard(
        context,
        title: '药物存量仪表盘',
        subtitle: '追踪药物存量与本地用药提醒',
        icon: Icons.medication_liquid_outlined,
        gradientColors: [const Color(0xFFF5A9B8), const Color(0xFF5BCEFA)],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const InventoryDashboardScreen()),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: '血药浓度模拟',
        subtitle: 'Oyama\'s HRT Tracker · PK 药代动力学测算',
        icon: Icons.stacked_line_chart_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    PKSimulationScreen(genderIdentity: genderIdentity)),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: '知识库 (Wiki)',
        subtitle: genderIdentity == GenderIdentity.ftm
            ? '包含 ftm.wiki 等'
            : '包含 mtf.wiki 等',
        icon: Icons.menu_book_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => WikiListPage(identity: genderIdentity)),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: '激素换算器',
        subtitle: 'E2/T/PRL 等单位实时双向换算',
        icon: Icons.balance_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const HormoneConverterScreen()),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: '声音训练辅助',
        subtitle: '基于 VFS Tracker 的嗓音训练工具集',
        icon: Icons.mic_external_on_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const VoiceTrainingHomeScreen()),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: '友善医疗名录',
        subtitle: '全国跨性别友善医疗机构',
        icon: Icons.local_hospital_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const MedicalDirectoryListScreen()),
          );
        },
      ),
    ];
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    List<Color> gradientColors = const [Color(0xFF5BCEFA), Color(0xFFF5A9B8)],
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 双色渐变图标 — Trans Prism 品牌色系
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, size: 44, color: Colors.white),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF999999),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class UserTab extends StatefulWidget {
  final String genderIdentity;
  final ValueChanged<String> onIdentityChanged;
  final String greetingName;
  final String namePrefix;
  final ValueChanged<String> onGreetingNameChanged;
  final ValueChanged<String> onNamePrefixChanged;

  const UserTab({
    super.key,
    required this.genderIdentity,
    required this.onIdentityChanged,
    required this.greetingName,
    required this.namePrefix,
    required this.onGreetingNameChanged,
    required this.onNamePrefixChanged,
  });

  @override
  State<UserTab> createState() => _UserTabState();
}

class _UserTabState extends State<UserTab> {
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
  void didUpdateWidget(UserTab oldWidget) {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 性别认同卡片
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('性别认同',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('修改后将立即更新首页推荐内容，并保存在本机。',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: widget.genderIdentity,
                  decoration: const InputDecoration(
                      labelText: '选择您的认同方向', border: OutlineInputBorder()),
                  items: GenderIdentity.values
                      .map((id) => DropdownMenuItem(
                          value: id, child: Text(GenderIdentity.label(id))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null && value != widget.genderIdentity) {
                      widget.onIdentityChanged(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 个人称呼设置卡片
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('个人称呼',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('设置首页问候语中显示的称呼和名字前缀，保存后立即生效。',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // 前缀在前，占用较小空间
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: _prefixOptions.containsKey(widget.namePrefix)
                            ? widget.namePrefix
                            : '__custom__',
                        decoration: const InputDecoration(
                            labelText: '前缀',
                            border: OutlineInputBorder(),
                            isDense: true),
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
                        width: 110,
                        child: TextField(
                          controller: _customPrefixController,
                          decoration: const InputDecoration(
                              labelText: '自定义前缀',
                              border: OutlineInputBorder(),
                              isDense: true),
                          onChanged: (v) {
                            if (v.isNotEmpty) widget.onNamePrefixChanged(v);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // 昵称在后面
                    Expanded(
                      child: TextField(
                        controller: _greetingController,
                        decoration: const InputDecoration(
                            labelText: '称呼（默认"伙伴"）',
                            border: OutlineInputBorder(),
                            isDense: true),
                        onChanged: (v) {
                          if (v.isNotEmpty) widget.onGreetingNameChanged(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 关于按钮
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BCEFA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF5BCEFA),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '关于',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '应用信息与第三方开源许可',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF86868B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 检查更新按钮
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleCheckUpdate(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BCEFA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF5BCEFA),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '检查更新',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '手动检测是否有新版本可用',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF86868B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 免责声明按钮
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DisclaimerViewScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5A9B8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFFF5A9B8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '免责声明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '医疗、数据与开源许可声明',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF86868B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 版本号 + 版权信息（居中靠底） ──
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '?.?.?';
            return Column(
              children: [
                Text(
                  '当前版本 v$version',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All Rights Reserved by TransPrism',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Wiki 列表页 — 支持离线模式开关
///
/// 对于 MtF.Wiki / FtM.Wiki / RLE.Wiki 三个可离线的 wiki，
/// 在右侧添加 Switch 开关控制离线模式。
class WikiListPage extends StatefulWidget {
  final String identity;
  const WikiListPage({super.key, required this.identity});

  @override
  State<WikiListPage> createState() => _WikiListPageState();
}

class _WikiListPageState extends State<WikiListPage> {
  /// 离线开关状态缓存
  final Map<String, bool> _offlineEnabled = {};

  /// 当前离线版本日期缓存
  final Map<String, String?> _offlineVersions = {};

  /// 静默下载中标记
  final Map<String, bool> _updating = {};

  /// 下载进度状态：null = 不在下载，0.0~1.0 = 下载中
  final Map<String, double?> _downloadProgress = {};

  /// 下载状态文字
  final Map<String, String> _downloadStatus = {};

  /// Wiki 配置：显示标题 → (wikiType, localSiteDirName, localIndexPath, onlineUrl)
  static const _wikiConfigs = {
    'MtF.Wiki': (
      'mtf',
      'mtf-wiki-site',
      '/zh-cn/docs/index.html',
      'https://mtf.wiki/zh-cn/',
    ),
    'FtM.Wiki': (
      'ftm',
      'ftm-wiki-site',
      '/index.html',
      'https://ftm.wiki/zh-cn/',
    ),
    'RLE.Wiki': (
      'rle',
      'rle-wiki-site',
      '/index.html',
      'https://rle.wiki/',
    ),
  };

  static const _prefsWikiHintDismissed = 'wiki_offline_hint_dismissed_forever';

  @override
  void initState() {
    super.initState();
    _loadOfflineStates();
  }

  /// 异步加载每个 wiki 的离线开关状态 + 版本信息
  Future<void> _loadOfflineStates() async {
    for (final displayTitle in _wikiConfigs.keys) {
      final (wikiType, _, _, _) = _wikiConfigs[displayTitle]!;
      final enabled = await WikiOfflineService.isOfflineEnabled(wikiType);
      final version =
          enabled ? await WikiOfflineService.readVersion(wikiType) : null;
      if (mounted) {
        setState(() {
          _offlineEnabled[wikiType] = enabled;
          _offlineVersions[wikiType] = version;
        });
      }
    }
    // 加载完成后批量检查更新 + 首次引导
    _checkAndUpdateAll();
    _showOnboardingHint();
  }

  /// 首次进入 Wiki 列表页时的引导提示
  Future<void> _showOnboardingHint() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsWikiHintDismissed) == true) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_for_offline, color: Color(0xFF5BCEFA)),
            SizedBox(width: 8),
            Text('离线版下载'),
          ],
        ),
        content: const Text(
          '每个知识库右侧的「下载」开关可开启离线版。\n\n'
          '开启后会自动下载最新离线包，之后即使没有网络也能正常阅读。\n\n'
          '如需关闭，再次点击开关即可删除离线数据。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('本次关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await prefs.setBool(_prefsWikiHintDismissed, true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5BCEFA),
            ),
            child: const Text('不再提示'),
          ),
        ],
      ),
    );
  }

  /// 批量检查所有已开启离线的 wiki 是否有更新
  Future<void> _checkAndUpdateAll() async {
    for (final displayTitle in _wikiConfigs.keys) {
      final (wikiType, _, _, _) = _wikiConfigs[displayTitle]!;
      if (!(_offlineEnabled[wikiType] ?? false)) continue;

      final result = await WikiUpdateManager().checkForUpdate(wikiType);
      if (result == null || !mounted) continue;

      final (latestDate, downloadUrl) = result;
      if (_updating[wikiType] == true) continue; // 已在更新中

      setState(() => _updating[wikiType] = true);

      final success = await WikiUpdateManager()
          .downloadUpdateSilently(wikiType, downloadUrl, latestDate);

      if (!mounted) return;

      setState(() {
        _updating[wikiType] = false;
        if (success) {
          _offlineVersions[wikiType] = latestDate;
        }
      });

      if (success) {
        _showSnackBar('$displayTitle 已更新至 $latestDate');
      }
    }
  }

  /// 获取 wiki 类型对应的显示标题
  String? _displayTitleForType(String wikiType) {
    for (final entry in _wikiConfigs.entries) {
      final (wt, _, _, _) = entry.value;
      if (wt == wikiType) return entry.key;
    }
    return null;
  }

  /// 处理离线开关切换
  Future<void> _handleOfflineToggle(String wikiType, bool newValue) async {
    if (newValue) {
      // ── 开启离线模式：触发下载 ──
      await _startDownload(wikiType);
    } else {
      // ── 关闭离线模式：确认弹窗 → 删除 ──
      await _confirmDisableOffline(wikiType);
    }
  }

  /// 开启离线：前台下载带进度
  Future<void> _startDownload(String wikiType) async {
    setState(() {
      _downloadProgress[wikiType] = 0.0;
      _downloadStatus[wikiType] = '准备中...';
    });

    final success = await WikiUpdateManager().downloadWithProgress(
      wikiType,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _downloadProgress[wikiType] = progress);
        }
      },
      onStatus: (status) {
        if (mounted) {
          setState(() => _downloadStatus[wikiType] = status);
        }
      },
    );

    if (!mounted) return;

    if (success) {
      await WikiOfflineService.setOfflineEnabled(wikiType, true);
      setState(() {
        _offlineEnabled[wikiType] = true;
        _downloadProgress.remove(wikiType);
        _downloadStatus.remove(wikiType);
      });
      _showSnackBar('${_displayTitleForType(wikiType) ?? wikiType} 离线版已就绪');
    } else {
      setState(() {
        _downloadProgress.remove(wikiType);
        _downloadStatus.remove(wikiType);
      });
      _showSnackBar('下载失败，请检查网络后重试');
    }
  }

  /// 关闭离线：确认弹窗
  Future<void> _confirmDisableOffline(String wikiType) async {
    // 计算预计节省空间
    final sizeStr =
        await WikiOfflineService.getOfflineDiskSizeFormatted(wikiType);
    final displayTitle = _displayTitleForType(wikiType) ?? wikiType;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭离线版'),
        content: Text(
          '确定关闭 $displayTitle 离线版？\n\n'
          '删除后将节省约 $sizeStr 空间，'
          '但后续将无法离线访问该 Wiki。\n\n'
          '确定要关闭吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 删除离线数据
    await WikiOfflineService.deleteAllOfflineData(wikiType);
    await WikiOfflineService.setOfflineEnabled(wikiType, false);

    setState(() {
      _offlineEnabled[wikiType] = false;
    });

    _showSnackBar('已删除 $displayTitle 离线版，节省约 $sizeStr 空间');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择知识库')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.identity == GenderIdentity.mtf) ...[
            _buildWikiTile(
                'MtF.Wiki', '跨性别女性进阶指南 (推荐)', Icons.star, Colors.pink),
            _buildWikiTile(
                'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book, Colors.blueGrey),
          ],
          if (widget.identity == GenderIdentity.ftm) ...[
            _buildWikiTile(
                'FtM.Wiki', '跨性别男性进阶指南 (推荐)', Icons.star, Colors.blue),
            _buildWikiTile(
                'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book, Colors.blueGrey),
          ],
          if (widget.identity == GenderIdentity.nb) ...[
            _buildWikiTile('MtF.Wiki', '跨性别女性进阶指南', Icons.star, Colors.pink),
            _buildWikiTile('FtM.Wiki', '跨性别男性进阶指南', Icons.star, Colors.blue),
            _buildWikiTile(
                'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book, Colors.blueGrey),
          ],
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              '其他参考资源',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          if (widget.identity == GenderIdentity.ftm)
            _buildWikiTile(
                'MtF.Wiki (已折叠)', '跨性别女性指南', Icons.folder_open, Colors.grey),
          if (widget.identity == GenderIdentity.mtf)
            _buildWikiTile(
                'FtM.Wiki (已折叠)', '跨性别男性指南', Icons.folder_open, Colors.grey),
          _buildWikiTile('2345.lgbt', '跨性别友好资源导航页', Icons.explore, Colors.teal),
          _buildWikiTile(
              '维基百科 (Wikipedia)', '中文维基百科跨性别词条', Icons.language, Colors.grey),
          const WikiLicenseNotice(),
        ],
      ),
    );
  }

  Widget _buildWikiTile(
    String displayTitle,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    // 判断是否为可离线的 wiki
    final hasOffline = _wikiConfigs.containsKey(displayTitle);
    final wikiType = hasOffline ? _wikiConfigs[displayTitle]!.$1 : null;

    // 下载进度
    final downloading =
        wikiType != null && _downloadProgress.containsKey(wikiType);
    final progress = wikiType != null ? _downloadProgress[wikiType] : null;
    final statusText = wikiType != null ? _downloadStatus[wikiType] : null;

    // 静默更新中
    final updating = wikiType != null && (_updating[wikiType] ?? false);

    // 离线开关状态（仅对可离线 wiki 有效）
    final switchValue =
        wikiType != null ? (_offlineEnabled[wikiType] ?? false) : false;

    // 版本信息
    final version = wikiType != null ? _offlineVersions[wikiType] : null;

    // 动态 subtitle
    String effectiveSubtitle = subtitle;
    if (updating) {
      effectiveSubtitle = '正在更新...';
    } else if (switchValue && version != null) {
      effectiveSubtitle = '离线版 · $version';
    }

    Widget trailing;
    if (downloading) {
      // 下载中：显示进度条 + 状态文字
      trailing = SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress != null)
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 3,
                ),
              ),
            if (statusText != null)
              Text(
                statusText,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    } else if (updating) {
      // 静默更新中：小进度圈
      trailing = const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    } else if (hasOffline) {
      // 可离线的 wiki：显示 Switch + 提示文字
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            switchValue ? '当前模式：离线' : '当前模式：在线',
            style: TextStyle(
              fontSize: 11,
              color: switchValue ? const Color(0xFF5BCEFA) : Colors.grey,
            ),
          ),
          Tooltip(
            message: switchValue ? '已开启离线版' : '点击开启离线版下载',
            child: Switch(
              value: switchValue,
              onChanged: (v) => _handleOfflineToggle(wikiType!, v),
              activeColor: const Color(0xFF5BCEFA),
            ),
          ),
        ],
      );
    } else {
      // 不可离线的 wiki：显示箭头
      trailing = const Icon(Icons.chevron_right);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(displayTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(effectiveSubtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing,
        onTap: () => _openWikiReader(context, displayTitle),
      ),
    );
  }

  void _openWikiReader(BuildContext context, String displayTitle) {
    // 可离线的 wiki（MtF / FtM / RLE）→ 统一 OfflineWikiScreen
    if (_wikiConfigs.containsKey(displayTitle)) {
      final (wikiType, siteDir, indexPath, onlineUrl) =
          _wikiConfigs[displayTitle]!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OfflineWikiScreen(
            wikiType: wikiType,
            title: displayTitle,
            onlineUrl: onlineUrl,
            localSiteDirName: siteDir,
            localIndexPath: indexPath,
          ),
        ),
      );
      return;
    }

    // 其他 wiki → WikiWebScreen
    final config = WikiCatalog.fromDisplayTitle(displayTitle);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂不支持该知识库')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WikiWebScreen(
          wikiId: config.id,
          title: displayTitle,
        ),
      ),
    );
  }
}
