import 'package:shared_preferences/shared_preferences.dart';

/// =============================================================================
/// HomeModuleVisibility — 首页模块可见性管理器
///
/// 使用 SharedPreferences 持久化用户对首页各模块的显示偏好。
/// 每个模块有一个唯一的 String key，对应一个 bool 值（true=显示）。
///
/// 首次启动时，默认开启 5 个最核心模块，其余默认关闭，
/// 确保首页初次展示时内容丰富且排版充实。
///
/// 使用 Schema 版本号管理新增模块的默认值迁移。
/// =============================================================================
class HomeModuleVisibility {
  HomeModuleVisibility._();

  // ── 模块 Key 常量 ──
  static const String keyGreeting = 'home_module_greeting';
  static const String keyMedStock = 'home_module_med_stock';
  static const String keyPkSim = 'home_module_pk_sim';
  static const String keyVoiceTraining = 'home_module_voice_training';
  static const String keyMedicalDirectory = 'home_module_medical_directory';
  static const String keySvgLibrary = 'home_module_svg_library';
  static const String keyImageConverter = 'home_module_image_converter';
  static const String keyHormoneConverter = 'home_module_hormone_converter';
  static const String keyBraCalculator = 'home_module_bra_calculator';

  /// SP 初始化标记 Key（无此标记即为首次启动）
  static const String _initFlagKey = 'home_modules_initialized';

  /// Schema 版本号，用于新增模块时自动填充默认值
  /// 每次新增模块（尤其是 coreKeys 中的模块）时 +1
  static const String _schemaVersionKey = 'home_modules_schema_version';
  static const int _currentSchemaVersion = 2;

  /// 所有模块的 key 列表，用于遍历
  static const List<String> allKeys = [
    keyGreeting,
    keyMedStock,
    keyPkSim,
    keyVoiceTraining,
    keyMedicalDirectory,
    keySvgLibrary,
    keyImageConverter,
    keyHormoneConverter,
    keyBraCalculator,
  ];

  /// 6 个核心模块（首次启动默认开启）
  static const Set<String> coreKeys = {
    keyGreeting,
    keyMedStock,
    keyPkSim,
    keyVoiceTraining,
    keyMedicalDirectory,
    keyBraCalculator,
  };

  /// 模块显示名称映射
  static const Map<String, String> moduleLabels = {
    keyGreeting: '问候语',
    keyMedStock: '药物存量',
    keyPkSim: '血药浓度模拟',
    keyVoiceTraining: '声音训练',
    keyMedicalDirectory: '友善医疗名录',
    keySvgLibrary: '图解资源 (SVG库)',
    keyImageConverter: '图片格式转换',
    keyHormoneConverter: '激素换算器',
    keyBraCalculator: '罩杯计算器',
  };

  /// 模块图标映射
  static const Map<String, String> moduleIcons = {
    keyGreeting: '👋',
    keyMedStock: '💊',
    keyPkSim: '📈',
    keyVoiceTraining: '🎤',
    keyMedicalDirectory: '🏥',
    keySvgLibrary: '🖼️',
    keyImageConverter: '🔄',
    keyHormoneConverter: '⚖️',
    keyBraCalculator: '📏',
  };

  /// 从 SharedPreferences 读取所有模块可见性。
  ///
  /// 首次启动（无初始化标记）时：
  ///   - 5 个核心模块 → true
  ///   - 其余模块 → false
  /// 并写入标记，后续读取全部依赖 SP 中已存储的值。
  ///
  /// Schema 升级时（如新增核心模块），自动将新模块设为 true。
  static Future<Map<String, bool>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool(_initFlagKey) == true;
    final map = <String, bool>{};

    if (isInitialized) {
      // 检查 Schema 版本，处理模块新增/变更
      final savedVersion = prefs.getInt(_schemaVersionKey) ?? 1;

      for (final key in allKeys) {
        if (savedVersion < _currentSchemaVersion && coreKeys.contains(key)) {
          // Schema 升级：核心模块默认开启（覆盖旧版可能错误保存的 false）
          map[key] = true;
          await prefs.setBool(key, true);
        } else if (prefs.containsKey(key)) {
          map[key] = prefs.getBool(key) ?? false;
        } else {
          // 非核心新增模块：默认关闭
          map[key] = coreKeys.contains(key);
        }
      }

      // 升级 Schema 版本
      if (savedVersion < _currentSchemaVersion) {
        await prefs.setInt(_schemaVersionKey, _currentSchemaVersion);
      }
    } else {
      // 首次启动：核心开启，其余关闭，并写入标记和 Schema 版本
      for (final key in allKeys) {
        final defaultValue = coreKeys.contains(key);
        map[key] = defaultValue;
        await prefs.setBool(key, defaultValue);
      }
      await prefs.setBool(_initFlagKey, true);
      await prefs.setInt(_schemaVersionKey, _currentSchemaVersion);
    }

    return map;
  }

  /// 保存单个模块的可见性
  static Future<void> save(String key, bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, visible);
  }

  /// 批量保存所有模块的可见性
  static Future<void> saveAll(Map<String, bool> visibility) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in visibility.entries) {
      await prefs.setBool(entry.key, entry.value);
    }
  }

  /// 重置所有模块为核心默认值
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in allKeys) {
      await prefs.setBool(key, coreKeys.contains(key));
    }
  }
}
