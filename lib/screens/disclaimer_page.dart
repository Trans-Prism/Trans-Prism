import 'dart:async';

import 'package:flutter/material.dart';

/// 首次启动强制展示的免责声明页
///
/// 包含：网络免责声明 + 血药浓度模拟免责声明。
/// 用户必须：
///   1. 等待倒计时结束（强制阅读时间）
///   2. 滚动到页面最底部（确保已阅读全部内容）
///   3. 勾选同意
/// 三项均满足后方可点击"同意并继续"。
class DisclaimerPage extends StatefulWidget {
  final Future<void> Function() onAccepted;

  const DisclaimerPage({super.key, required this.onAccepted});

  @override
  State<DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends State<DisclaimerPage> {
  /// 强制阅读时长（秒）
  static const int _mandatorySeconds = 8;

  bool _agreed = false;
  bool _isSaving = false;
  bool _hasScrolledToBottom = false;
  int _remainingSeconds = _mandatorySeconds;

  final ScrollController _scrollController = ScrollController();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startCountdown();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 监听滚动位置，当接近底部时标记 _hasScrolledToBottom
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    // 距离底部不足 40px 即视为已滚动到底
    if (current >= maxScroll - 40 && !_hasScrolledToBottom) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  /// 启动倒计时
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remainingSeconds = 0);
      } else {
        if (mounted) setState(() => _remainingSeconds--);
      }
    });
  }

  /// 按钮是否可用
  bool get _canConfirm =>
      _agreed && !_isSaving && _remainingSeconds == 0 && _hasScrolledToBottom;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isSaving = true);
    try {
      await widget.onAccepted();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 构建按钮文字（根据当前进度动态变化）
  String get _buttonLabel {
    if (_isSaving) return '';
    if (_remainingSeconds > 0) {
      return '请阅读全部声明 (剩余 $_remainingSeconds 秒)';
    }
    if (!_hasScrolledToBottom) {
      return '请先将声明滚动至底部';
    }
    if (!_agreed) {
      return '请勾选上方"我已阅读并同意"';
    }
    return '同意并继续';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            /// 顶部进度提示栏（更醒目的设计）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: _canConfirm ? Colors.green.shade50 : Colors.orange.shade50,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          _canConfirm ? Colors.green : Colors.orange.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _canConfirm ? Icons.check : Icons.access_time,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _buildStatusText(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _canConfirm
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// 滚动内容区
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 标题 ──
                    Icon(Icons.gavel,
                        size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      '免责与使用声明',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '在使用本应用前，请您仔细阅读以下全部声明。',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),

                    // ── 声明一：网络免责声明 ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.red.shade300, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red.shade800, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '网络功能声明（请务必阅读）',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '本软件仅为本地文本阅读器和离线工具箱，绝不提供任何形式的 VPN、翻墙、代理或突破网络审查的功能。所有网络请求仅限于获取开源文本。',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 声明一的补充说明 ──
                    Text(
                      '网络声明补充说明',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 本应用不会在后台建立任何隐蔽网络通道。\n'
                      '• 您可随时在系统设置中撤销本应用的网络权限。\n'
                      '• 继续使用即表示您理解并接受上述限制。',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.6, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 28),

                    // ── 声明二：血药浓度模拟免责声明 ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.shade300, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.healing,
                                  color: Colors.orange.shade800, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '血药浓度模拟声明（请务必阅读）',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '本软件内置的血药浓度模拟功能仅供医师参考，所有模拟结果均基于公开的数学模型估算，不构成任何医疗建议。',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '请在医师指导下进行激素替代疗法（HRT），切勿仅凭模拟结果自行用药、调整剂量或更改用药方案。不当使用激素药物可能对健康造成严重危害。',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '开发者不对因使用本血药浓度模拟功能而导致的任何直接或间接后果承担法律责任。',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 声明二的补充说明 ──
                    Text(
                      '血药浓度模拟补充说明',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 模拟浓度仅为理论估算，实际血药浓度因个体差异（代谢、体重、肝功能等）会有显著差异。\n'
                      '• 请定期进行血液检测，以实际检测结果为准。\n'
                      '• 如果您正经历任何不适或副作用，请立即咨询医生。\n'
                      '• 18 岁以下用户请在监护人及医生指导下使用。',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.6, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 28),

                    // ── 声明正文末尾 ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '— 声明结束 —',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // 提供额外空间让底部可卷过
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),

            // ── 底部固定区域：步骤清单 + Checkbox + 按钮 ──
            Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 步骤进度条（始终可见） ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '继续前请完成以下步骤：',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              // 完成进度指示
                              Text(
                                '${[
                                  if (_remainingSeconds == 0) 1,
                                  if (_hasScrolledToBottom) 1,
                                  if (_agreed) 1,
                                ].length}/3',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _canConfirm
                                      ? Colors.green
                                      : Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildStepItem(
                            '阅读并等待 $_mandatorySeconds 秒',
                            _remainingSeconds == 0,
                            trailing: _remainingSeconds > 0
                                ? '${_remainingSeconds}s'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          _buildStepItem(
                            '滚动至页面底部',
                            _hasScrolledToBottom,
                          ),
                          const SizedBox(height: 4),
                          _buildStepItem(
                            '勾选"我已阅读并同意"',
                            _agreed,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Divider ──
                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // ── Checkbox + 按钮 ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CheckboxListTile(
                          value: _agreed,
                          onChanged: _isSaving ||
                                  (_remainingSeconds > 0 ||
                                      !_hasScrolledToBottom)
                              ? null
                              : (v) => setState(() => _agreed = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '我已阅读并同意上述声明',
                            style: TextStyle(
                              fontSize: 14,
                              color: (_remainingSeconds > 0 ||
                                      !_hasScrolledToBottom)
                                  ? Colors.grey.shade400
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _canConfirm ? _confirm : null,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor:
                                  _canConfirm ? null : Colors.grey.shade300,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _buttonLabel,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _canConfirm
                                          ? Colors.white
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部状态栏文本
  String _buildStatusText() {
    if (_remainingSeconds > 0 && !_hasScrolledToBottom) {
      return '请阅读全部声明并滚动至底部（剩余 $_remainingSeconds 秒）';
    }
    if (_remainingSeconds > 0) {
      return '请继续阅读，剩余 $_remainingSeconds 秒';
    }
    if (!_hasScrolledToBottom) {
      return '请将声明滚动至底部';
    }
    if (!_agreed) {
      return '请勾选"我已阅读并同意"';
    }
    return '已阅读完毕，可以继续';
  }

  /// 步骤列表项
  Widget _buildStepItem(
    String text,
    bool done, {
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: done ? Colors.green : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? Colors.green : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: done ? FontWeight.w600 : FontWeight.normal,
                color: done ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trailing,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
