/// Wiki 配置：在线站点 + 用于版本校验的 GitHub 源码仓库
class WikiConfig {
  final String id;
  final String title;

  /// 在线 Wiki 入口（与 Next-MtF-wiki / 官方站一致）
  final String webUrl;

  /// 内容源码仓库（如 MtF-wiki）
  final String contentOwner;
  final String contentRepo;
  final String contentBranch;

  /// 前端框架仓库（MtF 使用 Next-MtF-wiki）
  final String? frontendOwner;
  final String? frontendRepo;
  final String? frontendBranch;

  const WikiConfig({
    required this.id,
    required this.title,
    required this.webUrl,
    required this.contentOwner,
    required this.contentRepo,
    required this.contentBranch,
    this.frontendOwner,
    this.frontendRepo,
    this.frontendBranch,
  });

  bool get hasGithubSource =>
      contentRepo.isNotEmpty && contentBranch.isNotEmpty;

  String get githubCommitsApi =>
      'https://api.github.com/repos/$contentOwner/$contentRepo/commits/$contentBranch';

  String? get frontendCommitsApi {
    if (frontendOwner == null ||
        frontendRepo == null ||
        frontendBranch == null) {
      return null;
    }
    return 'https://api.github.com/repos/$frontendOwner/$frontendRepo/commits/$frontendBranch';
  }
}

class WikiCatalog {
  WikiCatalog._();

  static const WikiConfig mtf = WikiConfig(
    id: 'mtf',
    title: 'MtF.Wiki',
    webUrl: 'https://mtf.wiki/zh-cn/',
    contentOwner: 'project-trans',
    contentRepo: 'MtF-wiki',
    contentBranch: 'master',
    frontendOwner: 'project-trans',
    frontendRepo: 'Next-MtF-wiki',
    frontendBranch: 'main',
  );

  static const WikiConfig ftm = WikiConfig(
    id: 'ftm',
    title: 'FtM.Wiki',
    webUrl: 'https://ftm.wiki/zh-cn/',
    contentOwner: 'project-trans',
    contentRepo: 'FtM-wiki',
    contentBranch: 'main',
  );

  static const WikiConfig rle = WikiConfig(
    id: 'rle',
    title: 'RLE.Wiki',
    webUrl: 'https://rle.wiki/',
    contentOwner: 'project-trans',
    contentRepo: 'RLE-wiki',
    contentBranch: 'master',
  );

  static const WikiConfig wikipedia = WikiConfig(
    id: 'wikipedia',
    title: '维基百科',
    webUrl: 'https://zh.wikipedia.org/wiki/跨性别',
    contentOwner: '',
    contentRepo: '',
    contentBranch: '',
  );

  /// 2345.lgbt — 跨性别友好资源导航站
  static const WikiConfig lgbt2345 = WikiConfig(
    id: '2345lgbt',
    title: '2345.lgbt',
    webUrl: 'https://2345.lgbt/',
    contentOwner: 'project-trans',
    contentRepo: '2345.LGBT',
    contentBranch: 'main',
  );

  /// MioMtFWiki — 社区驱动的跨性别知识项目（在线版）
  static const WikiConfig mioMtf = WikiConfig(
    id: 'miomtf',
    title: 'MioMtFWiki',
    webUrl: 'https://kitsumio.github.io/MioMtFWiki/',
    contentOwner: 'kitsumio',
    contentRepo: 'MioMtFWiki',
    contentBranch: 'main',
  );

  static const Map<String, WikiConfig> _configs = {
    'mtf': mtf,
    'ftm': ftm,
    'rle': rle,
    'wikipedia': wikipedia,
    '2345lgbt': lgbt2345,
    'miomtf': mioMtf,
  };

  static const List<String> syncableIds = ['mtf', 'ftm', 'rle', '2345lgbt'];

  static WikiConfig? fromDisplayTitle(String displayTitle) {
    if (displayTitle.startsWith('MtF.Wiki')) return mtf;
    if (displayTitle.startsWith('FtM.Wiki')) return ftm;
    if (displayTitle.startsWith('RLE.Wiki')) return rle;
    if (displayTitle.contains('维基百科') || displayTitle.contains('Wikipedia')) {
      return wikipedia;
    }
    if (displayTitle.startsWith('2345.lgbt')) return lgbt2345;
    if (displayTitle.startsWith('MioMtFWiki')) return mioMtf;
    return null;
  }

  static WikiConfig require(String id) {
    final config = _configs[id];
    if (config == null) throw ArgumentError('未知 Wiki: $id');
    return config;
  }
}
