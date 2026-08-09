> ⭐ 如果这个项目对你有帮助，欢迎点个 Star 支持一下！制作与维护不易，也欢迎通过赞助支持项目持续更新。
> ⭐ If this project helps you, a Star is appreciated. Ongoing development and maintenance take time, and sponsorship is welcome.

# Vibe Island Menu Spacer

这个独立的 AppKit 小程序只创建一个可自校准宽度的 `NSStatusItem`，为 Vibe Island
的小黑窗口提供菜单栏占位。`/Applications/Vibe Island.app` 不会被改写、注入或重签名。
展开状态继续由 Vibe Island 自己处理。Vibe Island 紧凑窗口仍保持实测的
354 pt，不修改本体尺寸。占位程序根据菜单栏托管窗口的实时坐标自动校正，
避免多余留白在左右两侧来回变化。

## 自动绝对居中

```bash
cd /path/to/VibeIslandMenuSpacer
./scripts/run_temp.sh
```

程序每 0.5 秒读取占位按钮的真实屏幕坐标，再在 `354...418 pt` 的安全范围内
调整宽度，使占位按钮中心跟随主屏中心。在当前 3440pt 主屏上，Vibe Island
窗口中心和占位按钮中心都保持 `X=1720`。当前占位按钮实测为
`X=1534...1906`，紧凑区域为 `X=1543...1897`，左右各保留 9 pt，
不再使用 440/500 pt 的大范围固定留白。

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
