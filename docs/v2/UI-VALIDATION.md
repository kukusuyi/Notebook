# Notebook 2.0 UI 迭代验证记录

分支：`codex/v2.0-ui-refresh`，基于 `codex/v2.0-local-first`。版本仍为 2.0.0。验证环境为 macOS Apple Silicon，2026-09-22。

## 本次实现

- 共享主题目录、HCT 强调色色阶、三套浅深主题与跟随系统。清澈蓝按后续反馈改为低饱和雾蓝。
- 本机外观偏好增加纸面／流光玻璃／柔软糖果、现代黑体／圆润人文／书卷宋体，以及图片背景。旧偏好兼容，重置恢复默认；背景不上传后端，不随服务器切换清除。
- 字体使用系统可用字体并回退，设备之间可能显示不同字形。玻璃是 CSS backdrop-filter／Flutter 模糊导航效果，非 macOS 原生 Liquid Glass API。
- 桌面侧栏、平板导航栏、手机四项底栏，宽屏题库详情预览；手机单列卡片与筛选抽屉；公式内部滚动。
- 统一新增入口，已有草稿确认、保存优先、AI 可选、分析结果回退、元数据折叠与高级 JSON；编辑离开确认；密钥显示配置状态。
- Flutter 连接电脑→登录、外观与个人设置、导航、录题操作区、服务状态；保留服务器凭据与草稿隔离。

## 自动检查

| 检查 | 本次结果 |
| --- | --- |
| `npm test`（frontend） | 31 项通过：三预设浅深模式、极端强调色、偏好验证／存储、背景协议限制、草稿回退与密钥占位符隐藏 |
| `npm run build`（frontend） | 类型检查及生产构建通过；存在大包体积提示，未做额外代码分包 |
| `flutter test` | 41 项通过：主题对比度与持久化、旧颜色迁移、草稿隔离／AI 回退、主要页面组件、8 张 Golden 基线、大字体与横屏设置布局 |
| `flutter analyze --no-fatal-infos` | 无错误、无警告；48 条提示级事项，主要为旧 API 弃用与代码风格 |
| `python3 scripts/generate-themes.py --check` | 通过，共享 JSON 与 Flutter 生成目录一致 |
| `go test ./...` | 通过；集成测试需要本机临时监听端口，首次在沙箱中被阻止后已获准重跑 |
| 后端生命周期冒烟 | 通过：内嵌网页、端口回退、中文目录、独占锁、初始化、无模型 CRUD、父进程退出、备份恢复、JWT 与数据持久化 |
| Android release 构建 | 通过，测试签名 |
| 五目标后端及 Electron 交叉打包 | Windows x64、macOS Intel/Apple Silicon、Linux amd64/arm64；桌面包标注 ui-unsigned-test |

Golden 默认使用 Flutter 测试字体，以保证基线可重复。下方 Flutter 可读截图额外加载本机中文字体与 SDK 图标字体，仅供视觉审阅，不等同于 Android 真机截图。系统字体没有加入项目或发行包。

## 实际网页交互

使用本机合成测试账户和题目，未修改用户业务数据。

- 概览在 360、390、768、1024、1440px 宽度下检查，页面未横向溢出；导航分别切换为底栏／80px 栏／224px 侧栏。
- 1440px 题库点击详情，列表与详情双栏正常；390px 筛选抽屉可打开和关闭。
- 390px 手机网页完成统一新增→手动录入 LaTeX 题目与答案→保存→详情，无模型配置也可保存；相似题明确提示 Embedding 未配置。
- 六套浅深主题切换并检查布局；刷新保留主题。
- 新质感、字体与背景图片选择即时生效；刷新保留，移除背景有效。背景测试使用本项目截图，不涉及私人照片。

## 截图

- [新版雾蓝桌面概览](ui-screenshots/web-overview-new-blue.png)
- [桌面题库双栏](ui-screenshots/web-desktop-split.png)
- [手机浅色外观](ui-screenshots/web-blue-light.png)、[手机深色外观](ui-screenshots/web-blue-dark.png)
- [手机录题](ui-screenshots/web-mobile-editor.png)、[手机详情](ui-screenshots/web-mobile-detail.png)
- [Flutter 浅色外观](ui-screenshots/flutter_blue_light.png)、[Flutter 深色外观](ui-screenshots/flutter_blue_dark.png)

部分业务截图采集于同次迭代的早期蓝色配色阶段；最终雾蓝以新版概览与六套外观截图为准。

## 测试产物

`dist/` 不纳入 Git。

- `dist/Notebook-2.0.0-ui-android-test.apk`
- `dist/desktop/Notebook-2.0.0-macos-arm64-ui-unsigned-test.zip`
- `dist/desktop/Notebook-2.0.0-macos-x64-ui-unsigned-test.zip`
- `dist/desktop/Notebook-2.0.0-windows-x64-ui-unsigned-test.exe`
- `dist/notebook-2.0.0-linux-amd64.tar.gz`、`dist/notebook-2.0.0-linux-arm64.tar.gz`
- `dist/SHA256SUMS`

## 尚未执行，不能据此宣称完成验收

- Android／iOS 真机：照片选择权限、软键盘遮挡、原生返回手势、系统字体实际效果和局域网跨设备闭环。
- 更新后 Electron 窗口／托盘完整交互；Windows、macOS Intel、Linux 目标系统原生启动。本轮交叉打包通过不等于目标系统运行通过。
- 真实 OCR、LLM、Embedding 服务成功／失败联调，打印机或系统 PDF 对话框实际输出。
- 所有业务页面与六主题、全部尺寸、全部字体／质感组合的穷举视觉检查；屏幕阅读器、最大系统字体与真实系统减少透明度设置。
- 正式代码签名、公证和正式 Android keystore。当前包仅用于测试。

基础设施版本的其他验证见 `VALIDATION.md`。本记录仅描述 UI 迭代实际执行的检查，没有将旧版真机／桌面观察计入本轮验收。

## 2026-09-23 问题修复

草稿删除、Qwen 链接、桌面图片裁剪、错误归类、玻璃模式弹窗定位及独立答案 OCR 的本轮记录见 [UI-FIXES-2026-09-23.md](UI-FIXES-2026-09-23.md)。
