> ⭐ 如果这个项目对你有帮助，欢迎点个 Star 支持一下！制作与维护不易，也欢迎通过赞助支持项目持续更新。
> ⭐ If this project helps you, a Star is appreciated. Ongoing development and maintenance take time, and sponsorship is welcome.

# Vibe Island Menu Spacer

这个独立的 AppKit 小程序实时读取 macOS 菜单栏托管窗口的真实坐标。只有真实图标
与 Vibe Island 的 354 pt 紧凑区域相交时，程序才创建一个 `NSStatusItem` 把图标移到
小岛左侧；没有图标被遮挡时，占位自动隐藏且不占任何空间。`/Applications/Vibe Island.app` 不会
被改写、注入或重签名，展开状态继续由 Vibe Island 自己处理。

## 条件占位与绝对居中

```bash
cd /path/to/VibeIslandMenuSpacer
./scripts/run_temp.sh
```

程序每 0.25 秒读取每个菜单栏图标和占位窗口的真实坐标。判断始终基于“如果移除
占位后图标会在哪里”的还原布局，因此不会在启用和释放之间反复抖动。紧凑区域
始终按屏幕中心计算；在当前 3440 pt 主屏上为 `X=1543...1897`，中心固定为
`X=1720`。macOS 的菜单项插槽是离散的，程序会在每次登录和图标宽度变化后重新测量，
优先选择最接近小岛右边缘的原生插槽，再只调整这一个占位的长度。可见小岛始终保持
`354 pt` 且绝对居中；占位右侧只吸收 macOS 离散插槽无法消除的最小余量，左侧则按当前
冲突图标的真实宽度自动留出一枚图标的点击距离，把冲突项完整排到小岛左侧。图标增减或
宽度变化时会重新测量，不使用某次截图的固定偏移，也不会在左右方案之间来回切换。
占位启用后，菜单项仍由 macOS 原生承载，不生成静态图标副本。扩展只创建或释放一个
`NSStatusItem`，不读取、移动或改写 Vibe Island 的窗口，也不安装鼠标事件监听，因此小岛
宿主始终保持系统原位置，左侧图标仍由各自程序原生响应点击，扩展不需要辅助功能权限。
图标不足、未进入该区域时不做任何布局调整，也不会留下固定空白。占位的 autosave 身份
跨版本保持稳定，升级后会复用上次位置作为探测起点，但仍必须通过当前屏幕的实时几何校验，
因此登录重启、菜单图标增减和宽度变化都走同一套适配逻辑，而不是写死某次截图的坐标。若
Control Center 重排期间出现暂态几何，扩展会先释放占位并在有限冷却后重新测量同一冲突，
不会因为图标布局暂时不稳定而永久停止处理。

```bash
./scripts/run_installed.sh
```

展开层位于紧凑窗口下方，不参与占位尺寸计算。

## 安装、验证与回滚

```bash
./scripts/install.sh          # 安装到 ~/Applications，并注册用户登录启动
./scripts/stop_and_restore.sh # 立即释放 NSStatusItem，菜单栏恢复
./scripts/rollback.sh         # 停止程序、移除本 App，并恢复安装前备份（若有）
```

脚本均使用 `set -euo pipefail`；构建前先跑完整 `swift test`。构建会优先复用钥匙串中已有的
`Apple Development` 稳定签名（也可通过 `VIBE_ISLAND_CODESIGN_IDENTITY` 指定），避免每次
更新后的代码身份变化导致 macOS 重复识别权限；没有可用开发签名的机器才回退到临时签名。
安装时整包替换 App，不把新旧签名封套混在一起。
安装脚本会创建只含 `RunAtLoad` 的用户级 LaunchAgent，保证重新登录或重启后扩展继续运行；
它不会在你主动退出后立刻拉起，也不会启动或修改 Vibe Island。没有真实遮挡时，状态项会被
彻底移除，不残留 16 pt 隐形空位。需要改回时优先运行 `stop_and_restore.sh` 停止本次登录中的
运行，或运行 `rollback.sh` 同时卸载登录启动项和扩展。

构建产物放在项目隐藏目录 `.artifacts/`，避免 Spotlight 把开发副本显示成第二个 App；
真正运行的副本只在 `~/Applications/`。
