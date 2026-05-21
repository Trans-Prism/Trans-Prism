/// 云服务桩
///
/// 这些功能需要部署后端云服务才能正常运行。
/// 当前提供入口点说明和预期功能描述。
///
/// 参考：https://github.com/Ethanlita/vfs-tracker
/// 后端使用 AWS Serverless 架构（Cognito + API Gateway + Lambda + DynamoDB + S3）
class CloudServices {
  /// 嗓音分析服务（对应 vfs-tracker online-praat-analysis Lambda）
  ///
  /// 功能：
  /// - 上传录音文件进行声学分析
  /// - 计算基频 (F0)、Jitter、Shimmer、HNR 等核心指标
  /// - 生成分析图表和 PDF 报告
  ///
  /// 需要部署：
  /// - Lambda 函数：online-praat-analysis（容器镜像）
  /// - S3 存储桶
  /// - API Gateway 端点
  static const String voiceAnalysis = '嗓音分析 (Cloud Lambda)';

  /// 文件上传服务（对应 vfs-tracker SecureFileUpload + S3）
  ///
  /// 功能：
  /// - 安全上传录音文件到云端
  /// - 生成临时访问 URL
  /// - 文件类型验证
  ///
  /// 需要部署：
  /// - S3 存储桶（带预签名 URL）
  /// - Lambda 函数：getUploadUrl / getFileUrl
  static const String fileUpload = '文件上传 (Cloud S3)';

  /// PDF 报告生成（对应 vfs-tracker TestResultsDisplay）
  ///
  /// 功能：
  /// - 汇总测试数据生成 PDF 报告
  /// - 包含图表和指标
  /// - 支持下载和分享
  ///
  /// 需要部署：
  /// - Lambda 函数：generateReport
  /// - S3 存储桶
  static const String pdfReport = 'PDF 报告 (Cloud Lambda)';

  /// 获取服务状态描述
  static String getServiceDescription(String service) {
    switch (service) {
      case voiceAnalysis:
        return '完整声学分析（F0/Jitter/Shimmer/HNR）\n'
            '需部署 AWS Lambda + S3 后端';
      case fileUpload:
        return '安全上传录音到云端\n'
            '需部署 AWS S3 + Lambda 后端';
      case pdfReport:
        return '生成专业嗓音分析 PDF 报告\n'
            '需部署 AWS Lambda + S3 后端';
      default:
        return '需部署云端后端服务';
    }
  }
}
