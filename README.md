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
`X=1720`。占位窗口与紧凑小岛同为 `354 pt`，不会再为贴合离散菜单锚点而拉宽。
占位启用后，菜单项仍由 macOS 原生承载，不生成静态图标副本。Vibe Island 的透明宿主窗口
比可见的 354 pt 黑框更宽；当鼠标确实落在黑框外的原生菜单项上时，程序会在该次点击期间
临时让透明宿主退出命中区域，点击结束立即恢复，因此被移出的图标仍能打开其原菜单。点击
黑框本身、没有原生菜单项的位置以及普通窗口均不处理。程序不请求录屏权限；点击穿透依赖
macOS“辅助功能”中对本程序已有的一次授权，程序本身不会反复打开权限设置或弹出授权请求。
图标不足、未进入该区域时不做任何布局调整，也不会留下固定空白。

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
