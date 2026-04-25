# FlashSpace v4.16.74 合并影响说明

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

## 已验证项

- `xcodebuild -project FlashSpace.xcodeproj -scheme FlashSpace -configuration Debug -destination 'platform=macOS' build` 通过。
- `FlashSpace-Dev.app` 可单独启动。
- 短时间 smoke test 未产生新的 crash report。
- 正式版和 Dev 版 bundle id 不同，但不建议同时运行。

## 正式版打包注意事项

CLI 签名不放进业务代码变更里。Release 打包完成后，如果需要手工补签 app bundle 内的 CLI，可执行：

```bash
APP="/path/to/FlashSpace.app"
IDENTITY="Developer ID Application: <Team Name> (<Team ID>)"

codesign --force \
  --sign "$IDENTITY" \
  --options runtime \
  "$APP/Contents/Resources/flashspace"
```

如果只是本机自用、没有 Developer ID，也可以使用 ad-hoc 签名：

```bash
APP="/path/to/FlashSpace.app"

codesign --force \
  --sign - \
  --options runtime \
  "$APP/Contents/Resources/flashspace"
```

补签后建议验证：

```bash
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP/Contents/Resources/flashspace"
```

如果后续还要分发给其它机器，补签 CLI 后还需要重新签整个 `.app`，并按正常流程 notarize。
