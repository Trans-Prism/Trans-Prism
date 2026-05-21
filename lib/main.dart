import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/gender_identity.dart';
import 'models/wiki_config.dart';
import 'screens/about_screen.dart';
import 'screens/disclaimer_page.dart';
import 'screens/medical_directory/medical_directory_list_screen.dart';
import 'screens/wiki_web_screen.dart';
import 'screens/pk_simulation_screen.dart';
import 'screens/voice_training/voice_training_home.dart';
import 'services/wiki_sync_service.dart';
import 'widgets/wiki_license_notice.dart';
import 'widgets/loading_indicator.dart';
import 'storage/disclaimer_repository.dart';
import 'storage/gender_identity_repository.dart';

void main() {
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
                  color: const Color(0xFF5BCEFA),
                  onTap: () => onSelect(GenderIdentity.mtf),
                ),
                const SizedBox(height: 16),
                _buildSelectionButton(
                  context,
                  title: 'FtM (跨性别男性)',
                  subtitle: '展现男性特质 / 获取 FtM 实用指南',
                  icon: Icons.male,
                  color: const Color(0xFFF5A9B8),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: Colors.transparent,
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
          const Text(
            '请选择您需要使用的功能模块',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF86868B),
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
        title: '知识库 (Wiki)',
        subtitle: genderIdentity == GenderIdentity.ftm
            ? '包含 ftm.wiki 等'
            : '包含 mtf.wiki 等',
        icon: Icons.menu_book_rounded,
        gradientColors: const [Color(0xFF5BCEFA), Color(0xFF4FC3F7)],
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
        title: '血药浓度模拟',
        subtitle: 'HRT 药代动力学测算',
        icon: Icons.stacked_line_chart_rounded,
        gradientColors: const [Color(0xFFF5A9B8), Color(0xFFE573A0)],
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
        title: '声音训练辅助',
        subtitle: '基于 VFS Tracker 的嗓音训练工具集',
        icon: Icons.mic_external_on_rounded,
        gradientColors: const [Color(0xFF26C6DA), Color(0xFF0097A7)],
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
        gradientColors: const [Color(0xFFFFB74D), Color(0xFFFF8A65)],
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
    required List<Color> gradientColors,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大尺寸渐变图标 - 无背景圈
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
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF86868B),
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
      ],
    );
  }
}

class WikiListPage extends StatelessWidget {
  final String identity;
  const WikiListPage({super.key, required this.identity});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择知识库')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (identity == GenderIdentity.mtf) ...[
            _buildWikiTile(
                context, 'MtF.Wiki', '跨性别女性进阶指南 (推荐)', Icons.star, Colors.blue),
            _buildWikiTile(context, 'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book,
                Colors.blueGrey),
          ],
          if (identity == GenderIdentity.ftm) ...[
            _buildWikiTile(
                context, 'FtM.Wiki', '跨性别男性进阶指南 (推荐)', Icons.star, Colors.pink),
            _buildWikiTile(context, 'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book,
                Colors.blueGrey),
          ],
          if (identity == GenderIdentity.nb) ...[
            _buildWikiTile(
                context, 'MtF.Wiki', '跨性别女性进阶指南', Icons.star, Colors.blue),
            _buildWikiTile(
                context, 'FtM.Wiki', '跨性别男性进阶指南', Icons.star, Colors.pink),
            _buildWikiTile(context, 'RLE.Wiki', '现实生活体验与社会过渡指南', Icons.book,
                Colors.blueGrey),
          ],
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              '其他参考资源',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          if (identity == GenderIdentity.ftm)
            _buildWikiTile(context, 'MtF.Wiki (已折叠)', '跨性别女性指南',
                Icons.folder_open, Colors.grey),
          if (identity == GenderIdentity.mtf)
            _buildWikiTile(context, 'FtM.Wiki (已折叠)', '跨性别男性指南',
                Icons.folder_open, Colors.grey),
          _buildWikiTile(
              context, '2345.lgbt', '跨性别友好资源导航页', Icons.explore, Colors.teal),
          _buildWikiTile(context, '维基百科 (Wikipedia)', '中文维基百科跨性别词条',
              Icons.language, Colors.grey),
          const WikiLicenseNotice(),
        ],
      ),
    );
  }

  Widget _buildWikiTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openWikiReader(context, title),
      ),
    );
  }

  void _openWikiReader(BuildContext context, String displayTitle) {
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
