# Ubuntu 部署总览

本文档给出当前仓库推荐的 Ubuntu 生产部署方案，目标是把 Web、后端、数据库、对象存储、向量检索和 Android 发布链路统一起来，避免部署时每个模块各自为战。

> 冷知识： 你也可以用别的

## 1. 推荐架构

```text
Internet
  |
  v
Nginx :80/:443
  |-- /           -> frontend/dist
  |-- /api/       -> 127.0.0.1:8080
  |-- /docs       -> 127.0.0.1:8080
  |-- /healthz    -> 127.0.0.1:8080
  |
  v
math-notebook-backend.service
  |
  +-- MySQL 8
  +-- MinIO
  +-- Qdrant
  +-- DashScope / DeepSeek / Kimi / OpenAI Compatible APIs
```

## 2. 为什么推荐 systemd + Nginx

### Nginx 负责

- 托管 `frontend/dist` 静态资源
- 反向代理 `/api/v1`
- 反向代理 `/docs`
- 做 HTTPS、压缩、缓存控制
- 给 Vue Router 做 SPA 回退

### systemd 负责

- 守护 Go 后端进程
- 统一日志、重启策略和开机自启
- 通过 `Environment=` / `EnvironmentFile=` 传递配置
- 管控 MinIO 等二进制服务

## 3. 推荐服务器目录结构

建议在 Ubuntu 上使用单独目录，例如：

```text
/opt/math-notebook/
├── backend/
│   ├── math-notebook-backend
│   ├── configs/
│   │   └── config.yaml
│   ├── docs/
│   │   └── 标签系统提示词/
│   └── ocr_prompt.md
├── frontend/
│   └── dist/
├── minio/
│   ├── data/
│   └── config/
├── logs/
└── releases/
```

如果你想保留源码发布，也可以把整个仓库放在 `/opt/math-notebook/repo`，但生产上更推荐把“运行目录”和“源码目录”拆开。

## 4. 建议系统用户

建议创建专用用户，避免直接用 `root` 跑业务服务：

```bash
sudo useradd --system --home /opt/math-notebook --shell /usr/sbin/nologin mathnotebook
sudo mkdir -p /opt/math-notebook
sudo chown -R mathnotebook:mathnotebook /opt/math-notebook
```

MinIO 也建议单独用自己的系统用户：

```bash
sudo useradd --system --home /opt/minio --shell /usr/sbin/nologin minio-user
```

## 5. 推荐版本基线

建议至少满足下面的版本：

- Ubuntu `22.04 LTS` 或 `24.04 LTS`
- MySQL `8.x`

说明：

- 后端 `go.mod` 当前要求 `go 1.25.0`
- 前端没有强制 `engines`，但当前仓库本地环境是 Node `22.x`
- Flutter 客户端 `pubspec.yaml` 要求 Dart `>= 3.4.0`

## 6. 端口规划

建议这样规划端口：

| 服务 | 默认端口 | 是否对公网开放 | 说明 |
|---|---:|---|---|
| Nginx HTTP | 80 | 是 | 建议仅用于 301 跳转到 HTTPS |
| Nginx HTTPS | 443 | 是 | 用户统一入口 |
| Go Backend | 8080 | 否 | 仅本机或内网访问 |
| MySQL | 3306 | 否 | 后端使用 |
| MinIO API | 9000 | 否 | 后端上传和对象访问 |
| MinIO Console | 9001 | 否 | 管理端口，建议仅内网 |
| Qdrant | 6333 | 否 | 后端向量检索使用 |

## 7. 发布顺序

推荐严格按照下面的顺序：

1. 部署 MySQL，并导入初始化 SQL
2. 部署 MinIO，并创建 bucket
3. 准备 Qdrant，并验证连通性
4. 准备后端配置文件 `config.yaml`
5. 部署 Go 后端二进制，并接入 systemd
6. 构建并发布 `frontend/dist`
7. 配置 Nginx 站点、HTTPS 和 SPA 回退
8. 验证 Web 主流程
9. 构建 Android APK，并上传到 MinIO `apk/` 目录
10. 验证移动端版本检查接口

## 8. 上线前检查清单

### 基础环境

- Ubuntu 已更新系统包
- 时区已配置正确
- 防火墙已放行 80/443
- 业务端口未直接暴露公网

### 数据与依赖

- MySQL 已导入 [deployments/mysql/mysql.sql](../../deployments/mysql/mysql.sql)
- MinIO bucket 已创建
- MinIO bucket 可读写
- Qdrant 可访问

### 后端

- `config.yaml` 已替换默认密钥
- `jwt.secret` 不再使用占位值
- `file.minio.secret_key` 不再使用占位值
- `imageOcr.api_key` 已配置
- `models[*].api_key` 已配置
- `embedding_model.api_key` 已配置
- `backend/ocr_prompt.md` 已随发布包带上
- `backend/prompts/chapter_router.md` 已随发布包带上
- `backend/prompts/chapters/` 已随发布包带上

### 前端

- `VITE_API_BASE_URL` 已指向生产 API 域名或反代路径
- Vue Router 已由 Nginx 做 `try_files` 回退
- 浏览器首屏正常打开

### Android

- release keystore 已配置
- `API_BASE_URL` 已替换为生产地址
- APK 已上传到 MinIO `apk/`
- `/api/v1/mobile/latest-version` 返回的 `apk_url` 可直接下载

## 9. 相关文档

- [基础依赖初始化](./02-基础依赖初始化.md)
- [后端部署（systemd）](./03-后端部署-systemd.md)
- [前端部署（Nginx）](./04-前端部署-Nginx.md)
- [Flutter Android 构建发布](./05-Flutter-Android构建发布.md)
