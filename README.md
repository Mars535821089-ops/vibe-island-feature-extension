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

程序每 0.5 秒读取每个菜单栏图标和占位窗口的真实坐标。判断始终基于“如果移除
占位后图标会在哪里”的还原布局，因此不会在启用和释放之间反复抖动。紧凑区域
始终按屏幕中心计算；在当前 3440 pt 主屏上为 `X=1543...1897`，中心固定为
`X=1720`。占位启用后，其左边缘自动对齐紧凑区域左边缘；图标不足、未进入该区域
时不做任何调整，也不会留下固定空白。

```bash
./scripts/run_installed.sh
```

展开层位于紧凑窗口下方，不参与占位尺寸计算。

## 安装、验证与回滚

```bash
./scripts/install.sh          # 只安装到 ~/Applications，不创建开机启动
./scripts/stop_and_restore.sh # 立即释放 NSStatusItem，菜单栏恢复
./scripts/rollback.sh         # 停止程序、移除本 App，并恢复安装前备份（若有）
```

脚本均使用 `set -euo pipefail`；构建前先跑完整 `swift test`，App 采用本地临时签名。
整个方案没有 LaunchAgent，也没有修改系统状态栏设置。需要改回时优先运行
`stop_and_restore.sh`，它只结束自身进程。

构建产物放在项目隐藏目录 `.artifacts/`，避免 Spotlight 把开发副本显示成第二个 App；
真正运行的副本只在 `~/Applications/`。
