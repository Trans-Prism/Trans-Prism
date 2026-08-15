import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/gender_identity.dart';
import '../../services/notification_service.dart';
import '../../services/permission_manager.dart';
import '../../services/theme_service.dart';
import '../../storage/disclaimer_repository.dart';
import '../../storage/gender_identity_repository.dart';
import '../../widgets/glass_card.dart';

/// 首次启动 Onboarding 向导
///
/// 一次性引导新用户完成：性别认同 → 明暗配色 → 配色风格 → 称呼前缀/称呼 →
/// 免责同意，最后落盘并标记 `onboarding_completed`，后续不再弹出。
///
/// 任意步骤均可「跳过」——跳过即接受全部默认值（MtF + 跟随系统 + 简约风 +
/// 无前缀 + 伙伴）并**跳转到「使用须知（免责声明）」步骤**；用户必须勾选同意
/// 免责后才能完成进入主界面，不允许直接跳过同意环节。
///
/// 严守 ADR-001（仅 SharedPreferences）/ ADR-002（纯 StatefulWidget + setState）/
/// ADR-010（双风格 GlassCard 自适应）。所有设置项复用既有 SP 键，不另起一套。
class OnboardingWizard extends StatefulWidget {
  final ThemeService themeService;

  /// 向导完成（含跳过）后回调，由 [AppRootController] 重新加载状态并重建。
  final Future<void> Function() onCompleted;

  const OnboardingWizard({
    super.key,
    required this.themeService,
    required this.onCompleted,
  });

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  late final PageController _pageController;
  int _currentStep = 0;

  // ── 选择状态（默认值 = Skip 默认值，单一来源） ──
  String _genderIdentity = GenderIdentity.mtf;
  ThemeMode _themeMode = ThemeMode.system;
  String _themeStyle = 'minimal'; // 'minimal' | 'liquid'
  String _namePrefix = ''; // '' = 不显示
  String _greetingName = ''; // 空 → 落盘时写 '伙伴'
  bool _disclaimerAgreed = false;

  // 称呼前缀选项（与 ProfileTab._prefixOptions 保持一致，避免双源漂移）
  static const Map<String, String> _prefixOptions = {
    '': '不显示',
    'Mr': 'Mr.',
    'Ms': 'Ms.',
    'Mrs': 'Mrs.',
    'Miss': 'Miss.',
    'Mx': 'Mx.',
    'Dr': 'Dr.',
  };

  bool _isCommitting = false;

  /// 权限授权状态：null=未请求，true=已授权，false=已拒绝。
  bool? _permissionGranted;

  /// 「少女祈祷中」过渡页的自动推进定时器（仅展示动画，后台无实际操作）。
  Timer? _prayingTimer;

  late final TextEditingController _greetingController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _greetingController = TextEditingController(text: _greetingName);
  }

  @override
  void dispose() {
    _prayingTimer?.cancel();
    _pageController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  // ── 步骤定义 ──
  static const int _stepWelcome = 0;
  static const int _stepPermission = 1; // 隐私与权限说明 + 系统权限申请
  static const int _stepDisclaimer = 6;
  static const int _stepPraying = 7; // 「少女祈祷中」过渡页（免责后、完成前）
  static const int _stepComplete = 8;
  static const int _totalSteps = 9;

  bool get _isLastStep => _currentStep == _stepComplete;

  /// 免责步骤的「下一步」需先勾选同意。
  bool get _canAdvanceFromDisclaimer =>
      _currentStep != _stepDisclaimer || _disclaimerAgreed;

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// 进入「少女祈祷中」过渡页后，延时自动推进到完成页（纯展示动画，无后台操作）。
  void _startPrayingTimer() {
    _prayingTimer?.cancel();
    _prayingTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted && _currentStep == _stepPraying) {
        _goToStep(_stepComplete);
      }
    });
  }

  void _next() {
    if (_isLastStep) {
      _commit();
      return;
    }
    if (!_canAdvanceFromDisclaimer) return;
    _goToStep(_currentStep + 1);
  }

  /// 触发系统级权限申请（通知 / 精确闹钟 / 忽略电池优化），并更新授权状态。
  /// 不推进步骤——推进由底部「继续」按钮负责，授权与否均可继续。
  Future<void> _requestPermissions() async {
    if (_isCommitting) return;
    bool granted = false;
    try {
      await NotificationService().requestPermission();
      await PermissionManager().requestAllCriticalPermissions();
      granted = await NotificationService().hasPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  void _back() {
    if (_currentStep > 0) _goToStep(_currentStep - 1);
  }

  /// 跳过：接受默认选择并跳转到「使用须知（免责声明）」步骤。
  /// 不自动同意免责、不直接完成——必须由用户在免责页勾选同意后才能继续并完成。
  void _skip() {
    if (_isCommitting) return;
    setState(() {
      _genderIdentity = GenderIdentity.mtf;
      _themeMode = ThemeMode.system;
      _themeStyle = 'minimal';
      _namePrefix = '';
      _greetingName = '';
      _disclaimerAgreed = false; // 强制用户在免责页手动勾选
    });
    _goToStep(_stepDisclaimer);
  }

  /// 落盘全部选择 + 标记完成，然后通知 AppRootController 重建。
  Future<void> _commit() async {
    if (_isCommitting) return;
    setState(() => _isCommitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. 性别认同
      await GenderIdentityRepository().saveIdentity(_genderIdentity);

      // 2. 主题模式 / 风格（走 ThemeService setter，触发 MaterialApp 重建）
      await widget.themeService.setThemeMode(_themeMode);
      await widget.themeService.setThemeStyle(_themeStyle);

      // 3. 称呼前缀 / 称呼（空称呼回退默认「伙伴」）
      await prefs.setString('user_name_prefix', _namePrefix);
      await prefs.setString(
        'user_greeting_name',
        _greetingName.isEmpty ? '伙伴' : _greetingName,
      );

      // 4. 免责同意
      await DisclaimerRepository().setAccepted();

      // 5. 完成标志（后续不再弹出向导）
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      await widget.onCompleted();
    } catch (e) {
      if (mounted) {
        setState(() => _isCommitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败：$e')),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //  主题模式 / 风格：选择即实时预览（调用 setter 即时生效）
  // ════════════════════════════════════════════════════════════
  Future<void> _selectThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await widget.themeService.setThemeMode(mode);
  }

  Future<void> _selectThemeStyle(String style) async {
    setState(() => _themeStyle = style);
    await widget.themeService.setThemeStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: _buildBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部进度槽：固定高度。欢迎/完成页留空占位，但保持高度恒定，
              // 避免翻页时 PageView 视口高度突变导致 animateToPage 卡顿/回弹。
              SizedBox(
                height: 64,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: (_currentStep != _stepWelcome &&
                          _currentStep != _stepPraying &&
                          _currentStep != _stepComplete)
                      ? _buildProgressHeader(isDark)
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _currentStep = i);
                    if (i == _stepPraying) {
                      _startPrayingTimer();
                    } else {
                      _prayingTimer?.cancel();
                    }
                  },
                  children: [
                    _buildWelcomeStep(isDark),
                    _buildPermissionStep(isDark),
                    _buildIdentityStep(isDark),
                    _buildThemeModeStep(isDark),
                    _buildStyleStep(isDark),
                    _buildGreetingStep(isDark),
                    _buildDisclaimerStep(isDark),
                    _buildPrayingStep(isDark),
                    _buildCompleteStep(isDark),
                  ],
                ),
              ),
              // 底部操作槽：固定高度，内容底对齐。欢迎页 CTA 已在卡片内，此处留空占位。
              SizedBox(
                height: 80,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomBar(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 背景：与主页统一，使用当前主题的 scaffoldBackgroundColor ──
  // 取消全屏高饱和渐变，改为主页同款极浅暖灰底（亮色 #F9F8F6 / 暗色随主题），
  // 让向导与全站视觉一致；品牌色仅作点缀（Logo / 主按钮 / 高亮文本）。
  BoxDecoration _buildBackground(BuildContext context) {
    return BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
  }

  // ════════════════════════════════════════════════════════════
  //  顶部进度
  // ════════════════════════════════════════════════════════════
  Widget _buildProgressHeader(bool isDark) {
    final active = _currentStep; // 1..5 为可跳过步骤
    const totalSkippable = 6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          if (_currentStep > _stepWelcome)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _back,
              tooltip: '上一步',
            ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalSkippable, (i) {
                final stepIndex = i + 1; // 1..5
                final filled = stepIndex <= active;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: filled ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFFF5A9B8)
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // 右上角跳过（与右下角跳过同义，提供双入口）
          TextButton(
            onPressed: _isCommitting ? null : _skip,
            child: Text(
              '跳过',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 0：欢迎
  // ════════════════════════════════════════════════════════════
  Widget _buildWelcomeStep(bool isDark) {
    // 与主页统一的设计 Token：深灰标题 / 中灰正文 / 品牌粉点缀。
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF8E8E93);
    final skipColor = isDark ? Colors.white70 : const Color(0xFF8E8E93);
    const subtitleColor = Color(0xFFC49EA8); // 低饱和灰粉（副标隐退，不抢主标题）
    const ctaColor = Color(0xFFF5A9B8); // 品牌粉（与全站主题色一致）
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // 主页同款白卡：简约风=纯白圆角+柔弥散阴影，液态风=毛玻璃。
          // CTA 与跳过均内嵌卡片底部，整卡垂直居中。
          GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top：六边形框 TP Logo + TRANS PRISM 字标
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo_in.png', height: 40),
                    const SizedBox(width: 10),
                    Text(
                      'TRANS PRISM',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                // Title
                Text(
                  '欢迎来到稳态光盒',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                const Text(
                  '—— 初始化向导 ——',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 14),
                // Body
                Text(
                  '让我们用几步，把光盒调到最贴合你的样子。\n所有选择仅保存在本机，随时可在「我的」里修改。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: bodyColor,
                  ),
                ),
                const SizedBox(height: 28),
                // 主按钮：进入向导（满宽圆角，品牌粉底白字 + 微弱粉阴影）
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isCommitting ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: ctaColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      elevation: 4,
                      shadowColor:
                          const Color(0xFFF5A9B8).withValues(alpha: 0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '进入向导',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // 次按钮：跳过（极简文字，加大点击域）
                TextButton(
                  onPressed: _isCommitting ? null : _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: skipColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('跳过',
                      style: TextStyle(fontSize: 14, color: skipColor)),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  通用：步骤标题
  // ════════════════════════════════════════════════════════════
  Widget _buildStepHeader(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2A28);
    final subColor = isDark ? Colors.white70 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: const Color(0xFFF5A9B8)),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, height: 1.5, color: subColor),
          ),
        ],
      ),
    );
  }

  // ── 通用选择卡 ──
  Widget _buildOptionTile({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final brand = accent ?? const Color(0xFFF5A9B8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        onTap: onTap,
        borderRadius: 16,
        padding: const EdgeInsets.all(14),
        surfaceColor:
            selected ? brand.withValues(alpha: isDark ? 0.22 : 0.16) : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: brand.withValues(alpha: selected ? 0.30 : 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: brand, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2A2A28),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: brand, size: 24),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 1：隐私与权限
  // ════════════════════════════════════════════════════════════
  Widget _buildPermissionStep(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF6A6A66);
    return ListView(
      children: [
        _buildStepHeader(
          isDark,
          Icons.shield_rounded,
          '隐私与权限',
          '在授权前，请了解我们的承诺。',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TransPrism 是一个公益的、无广告的离线优先项目。',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '我们绝不会发送任何广告内容，也不会调取您手机的任何内容，更不会上传您的数据。所有数据仅保存在您的设备本地。',
                  style: TextStyle(fontSize: 14, height: 1.6, color: bodyColor),
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                const SizedBox(height: 14),
                Text(
                  '接下来申请的系统权限仅用于「用药提醒」功能：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 通知权限：在用药时间准时提醒你\n'
                  '• 精确闹钟：确保提醒准时触发\n'
                  '• 忽略电池优化：防止系统杀后台导致漏提醒',
                  style: TextStyle(fontSize: 13, height: 1.7, color: bodyColor),
                ),
                const SizedBox(height: 10),
                Text(
                  '你可以随时在系统设置中撤销这些权限。',
                  style: TextStyle(fontSize: 12, height: 1.5, color: bodyColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // 授权按钮（状态化）：点击触发系统权限申请，样式随授权结果变化
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: _buildPermissionButton(),
          ),
        ),
      ],
    );
  }

  /// 权限授权按钮：根据 _permissionGranted 状态显示不同样式。
  Widget _buildPermissionButton() {
    if (_permissionGranted == true) {
      // 已授权：莫兰迪鼠尾草绿成功指示器（静态，不可重复点击）
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF7FA67D),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('已开启提醒权限',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    // 未授权或未请求：可点击触发系统权限申请（品牌粉，与全站主题色一致）
    return FilledButton.icon(
      onPressed: _isCommitting ? null : _requestPermissions,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF5A9B8),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        elevation: 3,
        shadowColor: const Color(0xFFF5A9B8).withValues(alpha: 0.30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.notifications_active_rounded, size: 20),
      label: Text(
        _permissionGranted == false ? '重新授予提醒权限' : '授予提醒权限',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 2：性别认同
  // ════════════════════════════════════════════════════════════
  Widget _buildIdentityStep(bool isDark) {
    return ListView(
      children: [
        _buildStepHeader(
          isDark,
          Icons.transgender,
          '你的认同方向',
          '我们会据此定制主页展示的内容。仅保存在本地。',
        ),
        _buildOptionTile(
          isDark: isDark,
          title: 'MtF (跨性别女性)',
          subtitle: '展现女性特质 / 获取 MtF 实用指南',
          icon: Icons.female,
          selected: _genderIdentity == GenderIdentity.mtf,
          onTap: () => setState(() => _genderIdentity = GenderIdentity.mtf),
        ),
        _buildOptionTile(
          isDark: isDark,
          title: 'FtM (跨性别男性)',
          subtitle: '展现男性特质 / 获取 FtM 实用指南',
          icon: Icons.male,
          selected: _genderIdentity == GenderIdentity.ftm,
          onTap: () => setState(() => _genderIdentity = GenderIdentity.ftm),
        ),
        _buildOptionTile(
          isDark: isDark,
          title: 'Non-Binary (非二元性别)',
          subtitle: '探索多元自我 / 获取通用支持',
          icon: Icons.transgender,
          accent: Colors.purple,
          selected: _genderIdentity == GenderIdentity.nb,
          onTap: () => setState(() => _genderIdentity = GenderIdentity.nb),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 2：明暗配色（棱镜梗）
  // ════════════════════════════════════════════════════════════
  Widget _buildThemeModeStep(bool isDark) {
    return ListView(
      children: [
        _buildStepHeader(
          isDark,
          Icons.settings_brightness,
          '明暗配色',
          '选择光盒的光影状态。选择即实时预览。',
        ),
        _buildOptionTile(
          isDark: isDark,
          title: '☀️ 白天模式：折射白昼',
          subtitle: '“把阳光散成七彩，全亮呈现。”',
          icon: Icons.light_mode_rounded,
          selected: _themeMode == ThemeMode.light,
          onTap: () => _selectThemeMode(ThemeMode.light),
        ),
        _buildOptionTile(
          isDark: isDark,
          title: '🌙 黑暗模式：吸收余光',
          subtitle: '“光线在此弯折，开启深夜护眼模式。”',
          icon: Icons.dark_mode_rounded,
          selected: _themeMode == ThemeMode.dark,
          onTap: () => _selectThemeMode(ThemeMode.dark),
        ),
        _buildOptionTile(
          isDark: isDark,
          title: '🌓 跟随系统：随光流转',
          subtitle: '“棱镜自适应：随系统的光影呼吸而变。”',
          icon: Icons.settings_brightness_rounded,
          selected: _themeMode == ThemeMode.system,
          onTap: () => _selectThemeMode(ThemeMode.system),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 3：配色风格
  // ════════════════════════════════════════════════════════════
  Widget _buildStyleStep(bool isDark) {
    return ListView(
      children: [
        _buildStepHeader(
          isDark,
          Icons.palette_rounded,
          '配色风格',
          '选择光盒的材质质感。选择即实时预览。',
        ),
        _buildOptionTile(
          isDark: isDark,
          title: '简约风',
          subtitle: '类 Claude、喜茶的小清新柔和圆角卡片',
          icon: Icons.circle_rounded,
          selected: _themeStyle == 'minimal',
          onTap: () => _selectThemeStyle('minimal'),
        ),
        _buildOptionTile(
          isDark: isDark,
          title: '毛玻璃',
          subtitle: 'Windows7 · 半透明模糊材质',
          icon: Icons.blur_on_rounded,
          selected: _themeStyle == 'liquid',
          onTap: () => _selectThemeStyle('liquid'),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 4：称呼前缀 + 称呼
  // ════════════════════════════════════════════════════════════
  Widget _buildGreetingStep(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2A28);
    final subColor = isDark ? Colors.white70 : Colors.black54;
    return ListView(
      children: [
        _buildStepHeader(
          isDark,
          Icons.waving_hand_rounded,
          '怎么称呼你',
          '用于首页问候语。留空即默认「伙伴」。',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '前缀',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _prefixOptions.entries.map((e) {
              final selected = _namePrefix == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                selectedColor: const Color(0xFFF5A9B8).withValues(alpha: 0.35),
                onSelected: (_) => setState(() => _namePrefix = e.key),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '称呼',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _greetingController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '默认：伙伴',
                hintStyle: TextStyle(color: subColor),
              ),
              style: TextStyle(color: titleColor, fontSize: 16),
              onChanged: (v) => _greetingName = v.trim(),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 5：免责声明（去冰冷化）
  // ════════════════════════════════════════════════════════════
  Widget _buildDisclaimerStep(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2A28);
    final bodyColor = isDark ? Colors.white70 : Colors.black87;
    return ListView(
      children: [
        _buildStepHeader(
          isDark,
          Icons.favorite_rounded,
          '使用须知',
          '在开始前，请花一点时间了解这两件小事。',
        ),
        _buildDisclaimerCard(
          isDark: isDark,
          icon: Icons.wifi_tethering_rounded,
          title: '关于网络',
          body: '稳态光盒本质上是一个本地阅读器与离线工具箱。它不会、也不能提供任何'
              'VPN、翻墙或代理功能——所有网络请求仅用于获取开源文本资料。\n\n'
              '你可以随时在系统设置里撤销它的网络权限，这不会影响本地数据。',
          accent: const Color(0xFF7C9EFF),
        ),
        const SizedBox(height: 14),
        _buildDisclaimerCard(
          isDark: isDark,
          icon: Icons.healing_rounded,
          title: '关于血药浓度模拟',
          body: '内置的血药浓度模拟基于公开数学模型估算，仅供医师参考，不构成任何'
              '医疗建议。\n\n'
              '请在医师指导下进行 HRT，切勿仅凭模拟结果自行用药或调整剂量。'
              '请以实际血液检测结果为准；如有不适请立即就医。18 岁以下请在'
              '监护人及医生指导下使用。',
          accent: const Color(0xFFF5A9B8),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: CheckboxListTile(
              value: _disclaimerAgreed,
              onChanged: (v) => setState(() => _disclaimerAgreed = v ?? false),
              activeColor: const Color(0xFFF5A9B8),
              title: Text(
                '我已阅读并同意以上说明',
                style: TextStyle(fontSize: 15, color: titleColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '开发者不对因使用本应用而导致的任何直接或间接后果承担法律责任。',
            style: TextStyle(fontSize: 12, height: 1.5, color: bodyColor),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF2A2A28);
    final bodyColor = isDark ? Colors.white70 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(fontSize: 14, height: 1.6, color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 6：少女祈祷中（过渡动画页，后台无实际操作）
  // ════════════════════════════════════════════════════════════
  Widget _buildPrayingStep(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subColor = isDark ? Colors.white70 : const Color(0xFF8E8E93);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 加载动画：品牌粉旋转指示器（仅展示，不做任何后台工作）
          const SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5A9B8)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '少女祈祷中...',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '稳态光盒正在为您专属定制...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: subColor),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  步骤 7：完成
  // ════════════════════════════════════════════════════════════
  Widget _buildCompleteStep(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 72, color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
          const SizedBox(height: 20),
          Text(
            '一切就绪 ✨',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '光盒已为你调好。随时可在「我的」里重新调整任何设置。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  底部操作栏
  // ════════════════════════════════════════════════════════════
  Widget _buildBottomBar(bool isDark) {
    // 欢迎页：CTA 与跳过已内嵌进中央卡片，底部栏留空。
    if (_currentStep == _stepWelcome) {
      return const SizedBox.shrink();
    }

    // 祈祷过渡页：自动推进，无操作按钮，底部栏留空。
    if (_currentStep == _stepPraying) {
      return const SizedBox.shrink();
    }

    // 完成页：进入
    if (_currentStep == _stepComplete) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: FilledButton(
          onPressed: _isCommitting ? null : _commit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF5A9B8),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
          ),
          child: _isCommitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('进入稳态光盒', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    // 中间步骤：上一步 / 下一步（免责未勾选则禁用）
    final nextLabel = _currentStep == _stepDisclaimer
        ? '同意并继续'
        : (_currentStep == _stepPermission
            ? (_permissionGranted == true ? '继续' : '暂不授权，继续')
            : '下一步');
    final canNext = _canAdvanceFromDisclaimer;
    // 「继续 / 下一步」统一使用品牌粉，与全站主题色一致。
    const nextBg = Color(0xFFF5A9B8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          if (_currentStep > _stepWelcome)
            TextButton(
              onPressed: _isCommitting ? null : _back,
              child: Text(
                '上一步',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          const Spacer(),
          FilledButton(
            onPressed: (_isCommitting || !canNext) ? null : _next,
            style: FilledButton.styleFrom(
              backgroundColor: nextBg,
              foregroundColor: Colors.white,
              disabledBackgroundColor: nextBg.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            child: _isCommitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(nextLabel, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
