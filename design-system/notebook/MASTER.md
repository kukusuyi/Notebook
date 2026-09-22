# Notebook 2.0 UI

本规范采用 ui-ux-pro-max 的简洁工具界面、触控、可访问性及响应式规则。配色以 `themes.json` 为唯一输入；Flutter 目录通过 `python3 scripts/generate-themes.py` 生成。Vue 直接读取 JSON。

- 预设：清澈蓝、暖纸墨、柔雾紫；默认清澈蓝／跟随系统。
- 用户强调色通过 Material HCT TonalPalette 生成。浅色 primary=40、onPrimary=100、container=95；深色 primary=80、onPrimary=20、container=25。语义状态色独立。
- 本机偏好 `notebook:appearance:v1`：`{version:1,preset,mode,accentSeed}`。不会上传或随切换服务器清除。移动端兼容旧 themeColorSeed。
- 系统中文字体，正文 16px，辅助信息 13–14px；4/8 间距，控件 8–12px 圆角；轻分隔线，无页面渐变或网格背景。
- ≥1024px 使用 224px 侧栏，768–1023px 使用导航栏，手机底部四项导航。详情和编辑不显示主导航。≥1280px 题库支持详情预览栏。
- 新增统一选择图片／手动方式，保存是主操作，AI 是可选辅助。已有草稿时明确选择继续或放弃；AI 结果可以回退到分析前的草稿。
- 表单分类信息折叠，JSON 为高级入口。移动端筛选使用抽屉，题库使用单列卡片。公式在内部横向滚动。
- 主题颜色不用于打印；打印保持黑白纸面。键盘焦点可见，减少动效时禁用过渡，Flutter 透明效果尊重辅助功能设置。

验收证据及限制见 `docs/v2/UI-VALIDATION.md`。
