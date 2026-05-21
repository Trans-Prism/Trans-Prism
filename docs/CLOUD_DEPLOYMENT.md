# 云端服务部署指南（Cloud Deployment Guide）

本文档说明如何部署嗓音训练模块所需的云端后端服务。
参考项目：[VFS Tracker](https://github.com/Ethanlita/vfs-tracker)

## 架构概述

```
┌─────────────┐     ┌──────────────┐     ┌───────────┐
│  Flutter App │────▶│  API Gateway │────▶│  Lambda   │
│  (本应用)    │     │  (REST API)  │     │  Functions │
└─────────────┘     └──────────────┘     └─────┬─────┘
                                               │
                                      ┌────────▼────────┐
                                      │  DynamoDB / S3   │
                                      └─────────────────┘
```

## 所需云服务

### 1. AWS Cognito - 用户认证
- **用途**: 用户注册、登录、会话管理
- **所需环境变量**:
  ```env
  VITE_COGNITO_USER_POOL_ID=your_user_pool_id
  VITE_COGNITO_USER_POOL_WEB_CLIENT_ID=your_client_id
  VITE_AWS_REGION=us-east-1
  ```

### 2. AWS API Gateway + Lambda - 后端 API
- **用途**: 处理嗓音分析请求、事件管理、文件上传等
- **Lambda 函数列表**:

| 函数 | 用途 | 部署方式 |
|------|------|---------|
| `online-praat-analysis` | 嗓音声学分析（F0/Jitter/Shimmer/HNR） | 容器镜像 |
| `addVoiceEvent` | 添加嗓音事件记录 | ZIP |
| `getVoiceEvents` | 获取嗓音事件列表 | ZIP |
| `getUploadUrl` | 生成 S3 预签名上传 URL | ZIP |
| `getFileUrl` | 生成文件访问 URL | ZIP |
| `getUserProfile` | 用户资料管理 | ZIP |
| `gemini-proxy` | AI 消息代理（可选） | ZIP |

- **所需环境变量**:
  ```env
  VITE_API_ENDPOINT=https://api.your-domain.com
  VITE_API_STAGE=prod
  ```

### 3. AWS DynamoDB - 数据存储
- **用途**: 存储用户资料、嗓音事件、测试结果
- **表结构**: 参考 `docs/data_structures.md`

### 4. AWS S3 - 文件存储
- **用途**: 存储录音文件、分析报告、用户头像
- **所需环境变量**:
  ```env
  VITE_S3_BUCKET=your-bucket-name
  ```

## 快速部署（使用 SAM）

```bash
# 1. 克隆 VFS Tracker 后端
git clone https://github.com/Ethanlita/vfs-tracker.git
cd vfs-tracker/infra

# 2. 部署后端
sam build --template template-production.yaml
sam deploy --guided

# 3. 部署在线嗓音分析 Lambda（容器）
cd ../lambda-functions/online-praat-analysis
./deploy.sh
```

## 本地开发

Flutter 应用中已标注需云端的功能会在 UI 上显示明确提示。要启用这些功能：

1. 部署上述 AWS 后端
2. 在 API 配置页面填写 OpenAI 兼容 API 的 endpoint 和 key
3. 在主配置中设置 AWS 环境变量

## 环境变量文件 (.env)

```env
# AWS 配置（必需）
AWS_REGION=us-east-1
COGNITO_USER_POOL_ID=xxx
COGNITO_CLIENT_ID=xxx
API_ENDPOINT=https://xxx.execute-api.xxx.amazonaws.com
S3_BUCKET=xxx

# AI 配置（可选）
AI_API_ENDPOINT=https://api.openai.com/v1
AI_API_KEY=sk-xxx
AI_MODEL=gpt-4o-mini
```
