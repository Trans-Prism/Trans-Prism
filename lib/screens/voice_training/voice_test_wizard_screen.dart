import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../models/voice_training/voice_event.dart';
import '../../services/backend_config_service.dart';
import '../../services/local_audio_analyzer.dart';
import '../../services/voice_training_service.dart';
import '../../widgets/audio_recorder_widget.dart';
import '../../widgets/backend_check_dialog.dart';
import 'surveys/rbh_survey_screen.dart';
import 'surveys/tvqg_survey_screen.dart';
import 'surveys/ovhs9_survey_screen.dart';

/// 嗓音测试向导步骤定义
class _WizardStep {
  final int id;
  final String title;
  final String instructions;
  final bool requiresRecording;
  final int recordingsNeeded;
  final List<String> recordingLabels;

  const _WizardStep({
    required this.id,
    required this.title,
    required this.instructions,
    this.requiresRecording = false,
    this.recordingsNeeded = 0,
    this.recordingLabels = const [],
  });
}

/// 嗓音测试向导页面
///
/// 从 vfs-tracker VoiceTestWizard.jsx 移植。
/// 8 步多步骤嗓音评估流程：
/// 0: 说明与同意
/// 1: 设备校准（静音+标准句）
/// 2: MPT + 持续元音 /a/
/// 3: 音域测定 - 滑音
/// 4: 定点音 + 共振峰
/// 5: 朗读指定散文
/// 6: 自由说话
/// 7: 主观量表
/// 8: 结果确认
class VoiceTestWizardScreen extends StatefulWidget {
  const VoiceTestWizardScreen({super.key});

  @override
  State<VoiceTestWizardScreen> createState() => _VoiceTestWizardScreenState();
}

class _VoiceTestWizardScreenState extends State<VoiceTestWizardScreen> {
  static const List<_WizardStep> _steps = [
    _WizardStep(
      id: 0,
      title: '说明与同意',
      instructions: '本工具旨在提供嗓音分析的参考数据，并非医疗诊断。\n\n'
          '过程需要约10分钟，请您在测试途中不要退出页面，否则所有进度都将会丢失。\n\n'
          '每次您完成一个片段的录音后，请点击"停止录音"，录音文件将保存到本地。如说错或失误，可点击"放弃"丢弃本段并重新录制。\n\n'
          '如果您准备好了，点击"下一步"即表示您同意以上条款。',
      requiresRecording: false,
    ),
    _WizardStep(
      id: 1,
      title: '设备与环境校准',
      instructions: '请在安静的环境中进行测试。\n\n'
          '首先，录制5秒钟的静音。\n'
          '然后，用正常音量朗读"他去无锡市，我到黑龙江"两遍。',
      requiresRecording: true,
      recordingsNeeded: 2,
      recordingLabels: [
        '点击开始录音，保持安静5秒，然后点击停止',
        '点击开始录音，朗读标准句，然后点击停止',
      ],
    ),
    _WizardStep(
      id: 2,
      title: '最长发声时 (MPT) + 稳定元音',
      instructions: '请用舒适的音量，尽可能长地发出元音 /a/。\n\n'
          '此步骤需要录制两次，我们会取效果最好的一次。',
      requiresRecording: true,
      recordingsNeeded: 2,
      recordingLabels: [
        '第一次 /a/（啊）发声，录制完成后请点击停止',
        '第二次 /a/（啊）发声，录制完成后请点击停止',
      ],
    ),
    _WizardStep(
      id: 3,
      title: '音域测定：滑音',
      instructions: '请从您最低的音平滑地唱到最高的音（上滑音），然后从最高的音平滑地唱到最低的音（下滑音）。\n\n'
          '上下滑音各需录制两次。\n\n'
          '提示：选择元音（如/a/或/u/），从舒适的中音开始，把声音顺滑地持续拉高到能达到的最高音（上滑音），再连续滑回最低音（下滑音）。',
      requiresRecording: true,
      recordingsNeeded: 4,
      recordingLabels: [
        '第一次上滑音',
        '第二次上滑音',
        '第一次下滑音',
        '第二次下滑音',
      ],
    ),
    _WizardStep(
      id: 4,
      title: '定点音 + 共振峰',
      instructions: '请分别用您最低和最高的可控音量，稳定地发出元音 /a/，各持续3-4秒。',
      requiresRecording: true,
      recordingsNeeded: 2,
      recordingLabels: [
        '最低音 /a/，录制完成后请点击停止',
        '最高音 /a/，录制完成后请点击停止',
      ],
    ),
    _WizardStep(
      id: 5,
      title: '朗读指定语句',
      instructions: '请按以下文字进行朗读：\n\n'
          '《第25小时的晨曦》\n\n'
          '请不要盯着倒影里的裂痕\n'
          '便断言那是不可饶恕的错构\n'
          '我们并非造物主打盹时的笔误\n'
          '更非黑夜里 滋生出的荒谬\n'
          '我们只是比别人多花了一点时间\n'
          '才在灵魂的深处辨认出自己 真正的名字\n\n'
          '收起那些廉价的自艾吧\n'
          '我们并不柔弱\n'
          '正如这世间所有如水般坚韧的姑娘\n'
          '能在大雨中奔跑，也能在悬崖边盛放\n\n'
          '眼泪与迷茫，是成长的必修课\n'
          '但请相信，我们的心脏同样为了爱与自由，滚烫地跳动着\n\n'
          '即使这具躯壳 曾是错置的迷宫\n'
          '也请不要害怕\n'
          '看呐，这个时代早已点亮了火把\n'
          '那些精密的、闪着银光的理性与科技\n'
          '就是我们手中 能够修改星图的笔\n\n'
          '它能抹去错误的注脚\n'
          '将那原本就属于你的 柔美、细腻与长发\n'
          '一点一点，诚实地归还\n\n'
          '哪怕前路曾被乌云封锁\n'
          '哪怕长夜 让人怀疑黎明的颜色\n'
          '但太阳从不会缺席\n'
          '它只是在等一个 最好的时刻\n\n'
          '这世上，从来没有太晚的春天\n'
          '哪怕是在深秋苏醒\n'
          '那努力冲破茧房、笨拙却勇敢的样子\n'
          '就是这世间 最可爱的少女',
      requiresRecording: true,
      recordingsNeeded: 1,
      recordingLabels: [
        '朗读全文，录制完成后请点击停止',
      ],
    ),
    _WizardStep(
      id: 6,
      title: '自由说话',
      instructions: '请围绕开放话题"介绍一下你最喜欢的食物"进行30-60秒的自由发言。',
      requiresRecording: true,
      recordingsNeeded: 1,
      recordingLabels: [
        '自由发言30-60秒，录制完成后请点击停止',
      ],
    ),
    _WizardStep(
      id: 7,
      title: '主观量表',
      instructions: '请根据您近期的嗓音情况，完成以下主观评估量表。',
      requiresRecording: false,
    ),
    _WizardStep(
      id: 8,
      title: '完成',
      instructions: '所有测试已完成！感谢您的参与。\n\n'
          '录音文件已保存在本地设备中。您可以查看测试记录回顾本次测试结果。',
      requiresRecording: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkBackendAndProceed(context, featureName: '嗓音综合测试向导');
    });
  }

  int _currentStep = 0;
  RBHScore? _rbhScore;
  List<int>? _tvqgScores;
  List<int>? _ovhs9Scores;
  bool _isSaving = false;
  String? _successMessage;

  // 当前步骤中已完成的录音索引
  final Set<int> _completedRecordings = {};
  // 当前步骤中正在录制的索引
  int? _currentRecordingIndex;

  // 所有步骤的录音文件路径 <stepId_index, filePath>
  final Map<String, String> _recordedFiles = {};
  // 本地分析结果
  List<LocalAnalysisResult>? _analysisResults;
  bool _isAnalyzing = false;

  bool get _isFirstStep => _currentStep == 0;
  bool get _isLastStep => _currentStep == _steps.length - 1;
  _WizardStep get _currentStepConfig => _steps[_currentStep];

  bool get _canProceed {
    if (_currentStepConfig.requiresRecording) {
      return _completedRecordings.length >= _currentStepConfig.recordingsNeeded;
    }
    if (_currentStep == 7) {
      // 量表步骤：可以选择不做
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('嗓音测试 - ${_currentStepConfig.title}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 步骤进度条
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: index <= _currentStep
                  ? () => setState(() => _currentStep = index)
                  : null,
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent
                      ? const Color(0xFF14B8A6)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 步骤标题
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${_currentStep + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _currentStepConfig.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 步骤内容
        if (_currentStep == 0)
          _buildIntroductionStep()
        else if (_currentStep == 7)
          _buildSurveyStep()
        else if (_currentStep == 8)
          _buildCompletionStep()
        else
          _buildRecordingStep(),

        const SizedBox(height: 24),

        // 导航按钮
        if (_currentStep != 8)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!_isFirstStep)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                      _completedRecordings.clear();
                      _currentRecordingIndex = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('上一步'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_currentStep == 7)
                FilledButton.icon(
                  onPressed: _canProceed ? _finishWizard : null,
                  icon: const Icon(Icons.check),
                  label: const Text('完成测试'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _canProceed
                      ? () {
                          setState(() {
                            _currentStep++;
                            _completedRecordings.clear();
                            _currentRecordingIndex = null;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_currentStep == 6 ? '跳过，进入量表' : '下一步'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildIntroductionStep() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB2EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF00838F)),
              SizedBox(width: 8),
              Text(
                '测试说明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00838F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentStepConfig.instructions,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF006064),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingStep() {
    final step = _currentStepConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 说明文字
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            step.instructions,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 录音任务列表
        ...List.generate(step.recordingsNeeded, (index) {
          final isCompleted = _completedRecordings.contains(index);
          final isActive = _currentRecordingIndex == index;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFE8F5E9)
                  : isActive
                      ? const Color(0xFFFFF3E0)
                      : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFFA5D6A7)
                    : isActive
                        ? const Color(0xFFFFCC80)
                        : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[300],
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.recordingLabels[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isCompleted ? FontWeight.w500 : FontWeight.normal,
                          color: isCompleted
                              ? const Color(0xFF2E7D32)
                              : Colors.grey[800],
                        ),
                      ),
                    ),
                    if (isCompleted)
                      const Icon(Icons.check_circle,
                          size: 20, color: Color(0xFF4CAF50)),
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 16),
                  AudioRecorderWidget(
                    label: '',
                    maxDurationSec: step.id == 2 ? 30 : 60,
                    onRecordingComplete: (path) async {
                      setState(() {
                        _completedRecordings.add(index);
                        _currentRecordingIndex = null;
                        final key = '${_currentStep}_$index';
                        _recordedFiles[key] = path;
                      });
                    },
                    onStartRecording: () {
                      setState(() => _currentRecordingIndex = index);
                    },
                    onDiscardRecording: () {
                      setState(() => _currentRecordingIndex = null);
                    },
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSurveyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '请根据您近期的嗓音情况，完成以下主观评估量表。\n您可以跳过不填，直接点击"完成测试"。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final score = await Navigator.push<RBHScore>(
                context,
                MaterialPageRoute(
                  builder: (context) => RBHSurveyScreen(
                    initialScore: _rbhScore,
                    onSave: (score) {
                      _rbhScore = score;
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.assignment),
            label: Text(
              _rbhScore != null ? 'RBH 量表（已完成）' : '填写 RBH 量表（粗糙度/气息感/嘶哑度）',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: _rbhScore != null
                    ? const Color(0xFF4CAF50)
                    : Colors.grey[300]!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push<List<int>>(
                context,
                MaterialPageRoute(
                  builder: (context) => TVQGSurveyScreen(
                    initialScores: _tvqgScores,
                    onSave: (scores) {
                      _tvqgScores = scores;
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.quiz),
            label: Text(
              _tvqgScores != null ? 'TVQ-G 问卷（已完成）' : '填写 TVQ-G 通用嗓音问卷（12项）',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: _tvqgScores != null
                    ? const Color(0xFF4CAF50)
                    : Colors.grey[300]!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push<List<int>>(
                context,
                MaterialPageRoute(
                  builder: (context) => OVHS9SurveyScreen(
                    initialScores: _ovhs9Scores,
                    onSave: (scores) {
                      _ovhs9Scores = scores;
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.hearing),
            label: Text(
              _ovhs9Scores != null ? 'OVHS-9 问卷（已完成）' : '填写 OVHS-9 嗓音不便指数（9项）',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: _ovhs9Scores != null
                    ? const Color(0xFF4CAF50)
                    : Colors.grey[300]!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionStep() {
    final surveyParts = <Widget>[];
    if (_rbhScore != null) {
      surveyParts.add(_resultRow(
          'RBH 量表',
          '${_rbhScore!.roughness}/${_rbhScore!.breathiness}/${_rbhScore!.hoarseness}',
          Icons.assignment));
    }
    if (_tvqgScores != null) {
      final total = _tvqgScores!.where((s) => s >= 0).fold(0, (a, b) => a + b);
      surveyParts.add(_resultRow('TVQ-G 问卷', '$total/48', Icons.quiz));
    }
    if (_ovhs9Scores != null) {
      final total = _ovhs9Scores!.where((s) => s >= 0).fold(0, (a, b) => a + b);
      surveyParts.add(_resultRow('OVHS-9 问卷', '$total/36', Icons.hearing));
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF14B8A6).withOpacity(0.1),
                const Color(0xFF0D9488).withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 64, color: Color(0xFF14B8A6)),
              const SizedBox(height: 16),
              const Text('测试完成！',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B))),
              const SizedBox(height: 12),
              Text('感谢您的参与！录音文件已保存在本地设备中。',
                  style: TextStyle(
                      fontSize: 14, height: 1.6, color: Colors.grey[700]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 录音步骤完成情况
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('测试步骤完成情况',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              ...List.generate(_steps.length - 2, (i) {
                final step = _steps[i];
                if (!step.requiresRecording) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: const Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('步骤 ${i + 1}: ${step.title}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700]))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // 量表结果摘要
        if (surveyParts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主观评估结果',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                ...surveyParts,
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 本地分析报告
        if (_analysisResults != null && _analysisResults!.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.analytics, size: 18, color: Color(0xFF14B8A6)),
                  SizedBox(width: 8),
                  Text('本地音频分析报告',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                ..._analysisResults!.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.stepName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: Color(0xFF00897B))),
                            const SizedBox(height: 4),
                            _metricRow('平均 F0',
                                '${r.averageF0.toStringAsFixed(1)} Hz'),
                            _metricRow('音域',
                                '${r.minF0.toStringAsFixed(0)}-${r.maxF0.toStringAsFixed(0)} Hz'),
                            _metricRow('稳定度 (σ)',
                                '${r.f0StdDev.toStringAsFixed(1)} Hz'),
                            _metricRow('有声占比',
                                '${(r.voicedRatio * 100).toStringAsFixed(0)}%'),
                            _metricRow(
                                '时长', '${r.durationSec.toStringAsFixed(1)}s'),
                            const Divider(height: 16),
                          ]),
                    )),
                if (_analysisResults!.length > 1) _buildOverallSummary(),
              ],
            ),
          ),

        // 保存结果按钮
        if (_successMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_successMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
          ),

        if (_analysisResults == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isAnalyzing ? null : _runLocalAnalysis,
              icon: Icon(_isAnalyzing ? Icons.hourglass_top : Icons.analytics),
              label: Text(_isAnalyzing ? '分析中...' : '🎯 生成本地分析报告'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                backgroundColor: const Color(0xFF00897B),
              ),
            ),
          ),
        if (_analysisResults != null) const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveAndFinish,
            icon: Icon(_isSaving ? Icons.hourglass_top : Icons.save),
            label: Text(_isSaving ? '保存中...' : '保存测试记录'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              backgroundColor: const Color(0xFF14B8A6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home),
          label: const Text('返回主页'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildOverallSummary() {
    final valid = _analysisResults!.where((r) => r.averageF0 > 0).toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    final avgs = valid.map((r) => r.averageF0).toList();
    final overall = avgs.reduce((a, b) => a + b) / avgs.length;
    final minAll = valid.map((r) => r.minF0).reduce((a, b) => a < b ? a : b);
    final maxAll = valid.map((r) => r.maxF0).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFE0F7FA),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('综合总结',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF00838F))),
        const SizedBox(height: 6),
        _metricRow('综合平均 F0', '${overall.toStringAsFixed(1)} Hz'),
        _metricRow('总体音域',
            '${minAll.toStringAsFixed(0)}-${maxAll.toStringAsFixed(0)} Hz'),
        Text(
          overall >= 180
              ? '🎉 平均基频在女性化嗓音目标范围内（180-250 Hz）！'
              : overall >= 160
                  ? '💪 接近女性化范围，继续练习提升！'
                  : '🌟 坚持训练，逐步提升音高！',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF006064)),
        ),
      ]),
    );
  }

  Widget _resultRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7B1FA2)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B1FA2))),
        ],
      ),
    );
  }

  Future<void> _runLocalAnalysis() async {
    if (_recordedFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('没有找到录音文件'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    setState(() => _isAnalyzing = true);
    final analyzer = LocalAudioAnalyzer();
    final fileList = _recordedFiles.entries.map((e) {
      final parts = e.key.split('_');
      final stepId = int.tryParse(parts[0]) ?? 0;
      final stepInfo = stepId < _steps.length ? _steps[stepId] : null;
      return {'path': e.value, 'stepName': stepInfo?.title ?? '步骤 $stepId'};
    }).toList();
    final results = await analyzer.analyzeFiles(files: fileList);
    if (mounted) {
      setState(() {
        _analysisResults = results;
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isSaving = true);

    try {
      final event = VoiceEvent.voiceTraining(
        rbhScore: _rbhScore,
        tvqgScores: _tvqgScores,
        ovhs9Scores: _ovhs9Scores,
        notes:
            '完成了全部${_steps.length - 1}步嗓音测试（${_steps[1].title} → ${_steps[6].title}）',
      );
      await VoiceTrainingService().saveEvent(event);

      // 保存测试完成标记
      if (mounted) {
        setState(() {
          _successMessage = '测试记录已保存！';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  void _finishWizard() {
    setState(() => _currentStep = 8);
  }
}
