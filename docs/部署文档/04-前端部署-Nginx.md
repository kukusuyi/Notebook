# 前端部署（Nginx）

本文档说明如何把 Vue Web 前端发布到 Ubuntu，并由 Nginx 托管。

## 1. 前端特性

前端是 Vue 3 + Vite 项目：

- [frontend/package.json](../../frontend/package.json)
- [frontend/vite.config.ts](../../frontend/vite.config.ts)

路由采用：

- [frontend/src/router/index.ts](../../frontend/src/router/index.ts)

当前使用 `createWebHistory()`，因此 Nginx 必须加 SPA 回退。

## 2. 构建前准备

安装依赖：

```bash
cd frontend
npm install
```

建议准备生产环境变量文件，例如：

```text
frontend/.env.production
```

内容示例：

```dotenv
VITE_API_BASE_URL=https://api.example.com
```

如果你选择“同域名 + Nginx 反代 `/api/`”的方式，也可以写：

```dotenv
VITE_API_BASE_URL=https://example.com
```

## 3. 构建前注意点

前端默认 API 地址是：

- `localStorage` 中的 `math-notebook:api-base-url`
- 否则回落到 `VITE_API_BASE_URL`
- 再否则回落到 `http://localhost:8080`

所以生产环境一定要做好两件事：

1. 构建时注入正确的 `VITE_API_BASE_URL`
2. 不要让浏览器里遗留错误的本地覆盖地址

## 4. 构建产物

执行：

```bash
cd frontend
npm run build
```

默认产物目录：

```text
frontend/dist/
```

建议上传到服务器：

```text
/opt/math-notebook/frontend/dist
```

## 5. 安装 Nginx

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable --now nginx
sudo systemctl status nginx
```

## 6. Nginx 站点配置

仓库模板：

- [deployments/nginx/math-notebook.conf.example](../../deployments/nginx/math-notebook.conf.example)

复制到：

```bash
sudo cp deployments/nginx/math-notebook.conf.example /etc/nginx/sites-available/math-notebook.conf
sudo ln -sf /etc/nginx/sites-available/math-notebook.conf /etc/nginx/sites-enabled/math-notebook.conf
```

按实际情况修改：

- `server_name`
- `root`
- 后端 upstream 地址

说明：

- 仓库里的示例是“先跑通 HTTP”的最小模板
- 如果你要上生产 HTTPS，建议在这个模板基础上再补 `listen 443 ssl`、证书路径和 80 -> 443 跳转

## 7. 配置要点

### 7.1 SPA 回退

必须包含：

```nginx
try_files $uri $uri/ /index.html;
```

否则用户刷新以下页面会直接 404：

- `/dashboard`
- `/questions`
- `/questions/123`
- `/tags`
- `/settings`

### 7.2 反代 API

后端建议只监听本机 `127.0.0.1:8080`，Nginx 统一代理：

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8080;
}
```

### 7.3 反代文档和健康检查

建议一起保留：

- `/docs`
- `/docs/openapi.json`
- `/healthz`

便于上线后排查问题。

### 7.4 静态缓存

对 `assets/` 目录建议加长期缓存，对 `index.html` 不要长缓存。

## 8. 检查并重载 Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 9. 发布后验证

### 9.1 打开首页

```text
https://example.com
```

### 9.2 刷新深层路由

重点测试：

- `/dashboard`
- `/questions`
- `/questions/1`
- `/questions/1/similar`
- `/settings`

### 9.3 检查 API 请求

打开浏览器开发者工具，确认前端请求是否发到期望地址。

## 10. 常见问题

### 1. 页面空白或接口全打到 localhost

原因：

- 没注入 `VITE_API_BASE_URL`
- 浏览器本地存储里保存了旧地址

处理：

- 重建前端
- 清掉浏览器 `math-notebook:api-base-url`

### 2. 刷新详情页 404

原因：

- Nginx 没有 `try_files ... /index.html`

### 3. 上传图片失败

可能原因：

- Nginx body size 太小
- 后端或 MinIO 配置不通

可在 Nginx 中适当增加：

```nginx
client_max_body_size 20m;
```

### 4. 跨域问题

如果前后端分域，虽然当前后端已放开 CORS，但生产上仍推荐优先走同域名反代，减少复杂度。
