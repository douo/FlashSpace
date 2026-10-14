# FlashSpace upstream 合并影响说明

## 2026-10-14：v4.18.79

### 合并范围

- 基线：本地 `55a62c2`，已集成 upstream `v4.16.74`。
- 目标：稳定版 `v4.18.79`（`1215291`），不包含其后的赞助文档更新。
- 集成分支：`integration/upstream-v4.18.79-local`。
- 回退分支：`backup/pre-upstream-merge-20261014-092901`；原集成分支也保留在原提交。
- 本次只合并和验证代码，不替换 `/Applications/FlashSpace.app`。

### 新增功能与修复

- 动态模式下，激活工作区会根据应用当前所在屏幕重新判断被替换的工作区，清除其旧活动记录，并隐藏其中未被新工作区或 Floating Apps 保留的应用。修复窗口跨屏移动后仍残留可见的问题（#612）。
- 工作区集成脚本使用串行队列维持执行顺序；切换前脚本仍等待完成，切换后脚本不再阻塞主线程。激活结束时刷新时间戳，避免延迟到达的焦点通知触发错误切换（#613）。
- 快捷键映射增加 ASCII 布局回退，并在布局切换时更新录制所用的反向映射，改善非拉丁布局下的快捷键注册和保存（#605）。
- Chromium 画中画识别兼容 `Picture in Picture` 和 `Picture-in-picture` 两种标题，忽略大小写（#579、#590）。
- 菜单栏标题可由脚本生成，可用于同时显示多屏的当前工作区；新选项默认关闭（#592）。
- CLI 新增 `list-workspaces --active`，并改进 Homebrew 安装检测、路径显示及脚本 PATH（#582、#591、#593）。
- 主窗口或设置窗口打开时显示 Dock 图标，关闭后隐藏；检查更新入口移到 General；Sparkle 从 2.8.1 更新到 2.9.6。

### 本地特性保留与冲突处理

- 15 个未被本轮上游改动触及的本地源码文件与合并前保持一致，涵盖跨屏焦点切换、快捷键和 CLI 入口、CoreGraphics 显示器解析、Chromium 焦点辅助、最小化及微小辅助窗口过滤、动态工作区 `canActivate` 判断。
- `WorkspaceManager` 保留实际应用屏幕的焦点记忆、AXWebArea 焦点修复及延迟 0.2 秒后的 `Esc` 回退调用、激活时的光标屏幕／主屏幕回退。
- 唯一文本冲突位于 `hideApps` 的筛选条件。保留本地诊断日志，并加入上游对被替换工作区应用的额外隐藏条件；参数命名为 `extraAppsToHide`，避免与最终筛选结果混淆。
- 当前工作区应用、Floating Apps、未分配应用设置及 Finder 保护条件仍先于额外隐藏条件执行。
- 保留原有 `DisplayName.current` / `NSScreen.main` 语义，不全局改为鼠标屏幕。
- 本地的 `focusNextScreen` / `focusPreviousScreen` 配置字段及 App、CLI 请求分支都保留。

### 升级和验证注意事项

- App 与 CLI 的 `listWorkspaces` 请求增加了必需的 `active` 字段，应同步更新两者。本次 Debug 验证前重新构建双架构 CLI，避免构建脚本复用旧协议的缓存二进制。
- Xcode 27 的 SwiftPM 默认构建系统把产物放在 `.build/out/Products/Release`，原先硬编码的架构目录会取到旧二进制。`project.yml` 改为一次构建 arm64/x86_64，并通过 `--show-bin-path` 获取产物路径；构建失败立即退出。未添加 CLI 签名命令。
- 菜单栏脚本默认关闭，现有标题模板继续使用。
- 源码对比及编译不能替代桌面操作验证；跨屏移动后的隐藏范围、快速切换、全屏应用、Chromium/Vimium C 焦点和输入法切换仍需在实际使用中回归。
- 上游未正式支持原生全屏应用，本地 CoreGraphics 回退仍有必要；上游 #618 的 Sequoia 15.8.1 稳定性报告尚未确定原因。

### 本次已完成的验证

- `xcodegen generate` 和 Debug `xcodebuild` 通过（Xcode 27.0 / macOS 26.6.2）。
- CLI 的 arm64/x86_64 通用二进制构建通过；实际执行了更新后的 CLI 构建脚本，并核对最终 App 内 CLI 的 `focus --help`、`list-workspaces --help`，确认跨屏选项和 `--active` 同时存在。
- App 和内嵌 CLI 均验证为指定自签名证书 `074B6E7241401A25C5E71A32F951B7BEE07A9CAC`；App 的 `codesign --verify --deep --strict` 通过。
- 自动源码对比确认上述 15 个本地文件、`WorkspaceManager` 的 6 个焦点／应用方法及激活前置回退逻辑与合并前一致；App 与 CLI 请求模型除新增 `active` 字段外与合并前一致。
- 本次变更的 26 个 App Swift 文件通过 SwiftLint 和 SwiftFormat。全量 SwiftLint 无错误，但有既有警告；全量 SwiftFormat 仍报告 4 个未改动的本地文件需要格式化，本次未改写这些文件。
- `git diff --check` 通过；项目生成文件中未引入 CLI codesign 步骤。
- 构建及检查日志位于 `.build/MergeValidation-v4.18.79/`，未进行桌面多屏操作、启动 Dev App 或安装替换。

## v4.16.74 历史合并记录

本文档记录本地分支合并 upstream `v4.16.74` 后的主要业务功能变化，以及对当前使用方式的影响。

## 合并目标

- 上游版本从本地基线升级到 `v4.16.74`。
- 保留本地已有行为修复：动态 Workspace 判断、多显示器焦点切换、Chromium 焦点修复、全屏应用显示器解析、忽略最小化窗口。
- 尽量采用 upstream 的新架构，避免大面积覆盖上游逻辑。
- CLI Release codesign patch 不混入本次业务合并，后续单独处理。

## 主要上游功能变化

### 1. 快捷键系统迁移

上游把快捷键系统从 `ShortcutRecorder` 迁移到了 `KeyboardShortcuts`。

使用影响：

- 快捷键录制 UI 和底层注册方式发生变化。
- 已有快捷键配置理论上仍通过 `AppHotKey` 保存，但新版本会同步到 `KeyboardShortcuts.Name`。
- 如果某些快捷键失效，优先到 Settings 里重新录制一次。
- 本地新增的 `Focus Next Screen` 和 `Focus Previous Screen` 已迁移到新系统。

本地保留：

- 多屏焦点切换热键仍存在。
- 快捷键名称已补充为 `focusNextScreen` / `focusPreviousScreen`。

### 2. 新增 Workspace Switcher

上游新增了 Workspace Switcher，类似工作区切换器 UI。

使用影响：

- 默认快捷键为 `opt+tab`。
- Settings 里新增 Workspace Switcher 设置页。
- 可以显示 workspace 列表、截图，并按最近激活时间排序。
- 如果你原来把 `opt+tab` 留给其他工具，需要重新设置或关闭这个功能。

本地保留：

- Workspace 激活逻辑仍保留本地动态 workspace fallback。
- 上游的 workspace activation time 也保留，用于 Workspace Switcher 排序。

### 3. Workspace 管理可暂停

上游新增 FlashSpace pause/resume 机制。

使用影响：

- 可以暂停 Workspace 管理，暂停后 workspace hotkeys 不会触发自动切换逻辑。
- 菜单栏和 General Settings 里会有对应入口或快捷键设置。
- 如果发现快捷键“没反应”，需要先确认 FlashSpace 是否处于 paused 状态。

本地保留：

- 本地 `activateWorkspace` 逻辑已接入 pause 检查。
- 未破坏本地动态 workspace 的可激活判断。

### 4. Workspace 自动分配应用

上游新增自动把 focused app 分配到当前 workspace 的能力。

使用影响：

- Settings 里新增 Auto-Assign Focused Apps To Active Workspace。
- 开启后，切换应用焦点可能自动改变 workspace 配置。
- 如果你习惯手动维护 workspace app 列表，建议默认关闭。

风险点：

- 该功能和动态 workspace、多屏幕焦点切换有交叉。
- 建议先保持关闭，确认日常切换稳定后再启用。

### 5. 每个 App 可单独设置 Auto Open

上游把 “workspace 激活时打开 app” 细化到 app 级别。

使用影响：

- 以前 workspace 打开时可能会启动全部未运行 app。
- 新版本只有标记了 `autoOpen == true` 的 app 才会被自动打开。
- 如果某些 workspace 激活后不再自动打开应用，需要检查 app 配置里的 auto-open 状态。

本地保留：

- 动态 workspace 中 “没有 running app 但允许 openAppsOnActivation” 的路径仍保留。
- 本地 `canActivate` 仍允许这类 workspace 被激活。

### 6. 重复激活当前 Workspace 可切回最近 Workspace

上游新增 “再次激活当前 workspace 时切回最近 workspace” 的选项。

使用影响：

- 开启后，按当前 workspace 的快捷键不会重复激活自身，而是切到最近 workspace。
- 这个行为只在设置开启时生效。

本地保留：

- 执行顺序为：先判断 upstream 的“切最近 workspace”，再执行本地 `canActivate` 判断。
- 因此不会破坏本地动态 workspace 的空 workspace 提示。

### 7. PiP 设置拆分和 Corner Hidden Apps

上游把 Picture-in-Picture 设置拆到独立设置页，并新增 Corner Hidden Apps。

使用影响：

- PiP 相关设置位置发生变化。
- 一些 app 可以隐藏到角落，而不是普通 hide。
- Workspace 切换时，上游新增的 corner-hidden 逻辑会参与 show/hide。

本地保留：

- 本地 `showApps` 中 Chromium web content focus 修复仍保留。
- 上游的 `showCornerHiddenAppIfNeeded` / `hideCornerHiddenAppIfNeeded` 也保留。

### 8. Space Control 内存和截图逻辑优化

上游优化了 Space Control 的内存占用和截图更新方式。

使用影响：

- Space Control 打开时应更省内存。
- 截图缓存和壁纸服务逻辑有变化。
- Workspace Switcher 也会复用部分截图能力。

对本地逻辑影响：

- 与本地动态 workspace/focus 逻辑没有直接冲突。
- 如果 Workspace Switcher 截图异常，优先检查新引入的截图缓存逻辑。

## 本地行为保留情况

### 1. 当前屏幕语义

保留原有逻辑，不把全局“当前屏幕”改成鼠标所在屏幕。

当前约定：

- upstream 新增的 `DisplayName.current` 本质仍是 `NSScreen.main?.localizedName`。
- `switchWorkspaceOnCursorScreen` 和本地 `focusNextScreen/focusPreviousScreen` 这类明确依赖鼠标位置的功能，仍使用鼠标所在屏幕。

使用影响：

- 日常 workspace 判断仍接近原来的行为。
- 只有“切换下一/上一屏幕焦点”会以鼠标位置作为起点。

### 2. 忽略最小化窗口

本地曾专门修过“最小化窗口造成幽灵显示器/错误焦点”的问题，本次合并已保留。

保留点：

- `NSRunningApplication.allDisplays` 会过滤最小化窗口。
- 方向焦点切换会过滤最小化窗口。
- 跨屏焦点切换会过滤最小化窗口。

使用影响：

- 最小化窗口不会让 dynamic workspace 误判应用仍在某个显示器上。
- focus 切换不会跳到最小化窗口。

### 3. Chromium unhide 后网页焦点修复

本地 `BrowserFocusHelper` 已保留。

使用影响：

- Chromium 系浏览器从 hidden 状态恢复后，会尝试把焦点放回 web content。
- 如果 AXWebArea focus 失败，会 fallback 模拟一次无修饰键 `Esc`。
- 这会改善 Vimium C 等扩展无法立即接收键盘事件的问题。

注意：

- fallback `Esc` 可能关闭网页弹层或退出输入状态。
- 当前按你的要求保留该行为。

### 4. Dynamic Workspace 显示器解析

本地 CoreGraphics fallback 已保留。

使用影响：

- 当 Accessibility API 拿不到全屏 app 或隐藏 app 的窗口显示器时，会尝试用 CoreGraphics 查询窗口。
- 这能降低动态 workspace 在全屏 app 场景下切换延迟或判断失败的概率。

### 5. Dynamic Workspace 激活判断

本地 `canActivate` 逻辑已保留。

使用影响：

- 动态 workspace 没有 running app、也不允许自动打开 app 时，会提示 “No Running Apps To Show”。
- 动态 workspace 没有 running app、但允许自动打开 app 时，仍可以激活并启动应用。

## 建议使用方式

- 合并后第一次使用，先只运行 `FlashSpace-Dev`，不要和正式版同时运行。
- 先确认快捷键设置，尤其是 `opt+tab` 是否和已有工具冲突。
- 默认先不要开启 Auto-Assign Focused Apps To Active Workspace。
- 如果快捷键无效，先检查 FlashSpace 是否 paused，再重新录制快捷键。
- 如果动态 workspace 行为异常，优先检查是否有最小化窗口、全屏窗口、或者 auto-open 配置变化。

## v4.16.74 已验证项（历史）

- `xcodebuild -project FlashSpace.xcodeproj -scheme FlashSpace -configuration Debug -destination 'platform=macOS' build` 通过。
- `FlashSpace-Dev.app` 可单独启动。
- 短时间 smoke test 未产生新的 crash report。
- 正式版和 Dev 版 bundle id 不同，但不建议同时运行。

## 当前本机签名规则

遵循 `/Users/tiou/.config/apple/codex-build-policy.md` 和
`/Users/tiou/.agents/skills/apple-signing-release/SKILL.md`。本机固定使用
`Tiou's Local Self-Signed`（`074B6E7241401A25C5E71A32F951B7BEE07A9CAC`），不得回退到 ad-hoc。

CLI 补签仍属于构建后验证／打包步骤，不向 `project.yml` 添加 CLI codesign 命令。
签名嵌套组件及 CLI 后，再签整个 App 并验证。可使用用户级辅助工具：

```bash
APP="/path/to/FlashSpace.app"
/Users/tiou/bin/apple-codesign "$APP/Contents/Resources/flashspace"
/Users/tiou/bin/apple-codesign "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dr - "$APP"
```

项目技能中的旧个人发布脚本仍使用 ad-hoc 签名，不符合当前规则，不能直接用于新发布。
正式打包应从已提交的干净工作区开始；安装前比较既有 App 的 designated requirement。
如需 Apple 公证或 App Store 分发，需另行使用 Apple 签发的身份及相应流程。
