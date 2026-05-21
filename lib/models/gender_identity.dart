/// 性别认同选项定义
class GenderIdentity {
  GenderIdentity._();

  static const String mtf = 'mtf';
  static const String ftm = 'ftm';
  static const String nb = 'nb';

  static const List<String> values = [mtf, ftm, nb];

  static String label(String id) {
    switch (id) {
      case mtf:
        return 'MtF (跨性别女性)';
      case ftm:
        return 'FtM (跨性别男性)';
      case nb:
        return 'Non-Binary (非二元性别)';
      default:
        return '未知';
    }
  }

  static String shortLabel(String id) {
    switch (id) {
      case mtf:
        return 'MtF';
      case ftm:
        return 'FtM';
      case nb:
        return '非二元';
      default:
        return '未知';
    }
  }

  static bool isValid(String? id) => id != null && values.contains(id);
}
