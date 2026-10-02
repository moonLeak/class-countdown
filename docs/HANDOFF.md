# 交接文档：交给 Claude Code 执行的开发任务

日期：2026-10-02
设计画布：https://claude.ai/artifact/R451PwaxXLoKW7kgQaWYCG（v7.8 为最新，位于画布最下方）
仓库：`https://github.com/moonLeak/class-countdown.git`，分支 `main`，上一个发布提交 `38615c8`（v1.1.0）
目标：把设计画布 v7.8 的设计落地成可运行的 App。

## 0. 起点

- 工作区有 5 个未提交改动：`DesignTokens.swift`、`EventCard.swift`、`CardStack.swift`、`PanelController.swift`，以及新文件 `RingIcon.swift`。内容见 `docs/DESIGN-v7-focus.md` 第 2 节（后卡露出条居中、右键菜单栏图标弹菜单、菜单栏进度环）。
- 这些改动已经过设计确认，但还没在本机编译验证。第一步先编译、验证、单独提交（见阶段 0）。
- `docs/` 目录是新增的，里面的文档和原型一并提交。
- 仓库没有测试目标。`build.sh` 是 `swiftc` 一条命令。给 `FocusEngine` 写单测需要新增 `Package.swift` 或单独的测试脚本，见阶段 3。

## 1. 设计依据与优先级

冲突时按以下顺序取值：

1. `docs/DESIGN-SPEC.md`
2. `docs/prototypes/*.dc.html` 源文件里的数值（这些原型可在浏览器中操作，需要画布的运行时，源文件主要用来读数值与交互逻辑）
3. `docs/prototypes/*.png` 截图
4. `docs/DESIGN-v7-focus.md` 的需求描述

## 2. 分阶段任务

每个阶段做完都要：本机编译通过、手动验证验收项、提交一次。阶段之间互相独立，可以单独回退。

### 阶段 0：整理现状

| 项 | 做法 |
|---|---|
| 编译与验证 | 运行构建命令，确认露出条、右键菜单、圆环图标工作 |
| `DS.peek` | 27 改为 21，露出条文字仍垂直居中 |
| 去掉百分比 | 事件卡右下角的百分比删除，只留左下角时间段。露出条右侧改为倒计时（`TimeFormat` 现有格式）。设置里“显示进度百分比”及其存储 key、文案一并删除 |
| 提交 | 分两个提交：一是已有的 5 个文件改动，二是 peek 与去百分比 |

验收：收起态后两张卡的右侧显示倒计时；展开态事件卡右下角没有数字；设置里没有百分比开关。

### 阶段 1：设置改为正规窗口

当前 `SettingsView` 在临时面板里，点其他地方会消失。改为标准窗口，规格见 DESIGN-SPEC 3.3 的 SettingsWindow，原型见 `docs/prototypes/Settings-Window-v78.dc.html` 与 `settings-*.png`。

| 项 | 做法 |
|---|---|
| 窗口 | `SettingsWindowController`，`NSWindow`，样式 `titled`、`closable`、`miniaturizable`、`resizable`，不设 `hidesOnDeactivate`，不是浮动面板。默认 540×600，最小 420×380 |
| 位置与大小 | `setFrameAutosaveName("SettingsWindow")`，记忆位置与大小 |
| 工具栏标签 | 通用、日历、专注、关于，使用 `NSToolbar`（`toolbarStyle = .preference`）或等价的 SwiftUI 标签实现，窗口标题随标签变化 |
| 激活策略 | App 是 `LSUIElement`。打开窗口时 `NSApp.setActivationPolicy(.regular)` 并激活，最后一个设置或统计窗口关闭后恢复 `.accessory` |
| 入口 | 浮窗齿轮、菜单栏右键菜单“设置”、Command+逗号 |
| 内容 | 通用（语言、登录时打开、菜单栏样式与显示内容、空闲时显示下一个日程）；日历（来源日历开关、包含全天事件、临近结束警示）；专注（时长、自动开始、常亮、写入日历）；关于（版本、退出）。专注页在阶段 4 之前可先放置占位但不接线 |
| 材质 | 窗口背景用系统材质（`NSVisualEffectView` 的 `.hudWindow` 或 SwiftUI `.glassEffect`），接近画布的 Liquid Glass 效果，不要照搬 HTML 的半透明色值 |

验收：点窗口外不消失；可拖动缩放，内容滚动；切标签有窗口标题变化；关闭后再打开位置与大小保持；关闭全部窗口后 Dock 图标消失。

### 阶段 2：菜单栏徽标样式

规格见 DESIGN-SPEC 3.3 的 MenuBarItem，原型 `docs/prototypes/MenuBar-Styles-v78.dc.html`、`menubar-*.png`。

| 项 | 做法 |
|---|---|
| 设置项 | `menubar.style`：`ring`（默认）或 `badge`；`menubar.badgeProgress`：是否随进度填充，默认开；`menubar.showNextWhenIdle`：空闲时显示下一个日程，默认开 |
| 渲染 | 新增 `BadgeIcon.swift`，用 `NSImage(size:flipped:drawingHandler:)` 绘制，`isTemplate = false`。高 20，圆角 6，内边距 8，文字 13 Medium 白色。底色为状态色 40%，进度填充为状态色 90% |
| 状态色 | 日程用日历色，临近结束用 `DS.Color.warn`，专注与休息用 `DS.Color.focus`，空闲（下一个日程）用灰 |
| 显示内容 | 沿用现有 `MenuBarContent`：仅图标、仅剩余时间、名称与剩余时间。徽标样式下“仅图标”显示空底色徽标无文字，需要你判断是否合理，不合理时徽标样式下隐藏该选项 |
| 明暗 | 在浅色和深色菜单栏下都检查文字可读，尤其橙色警示。需要时随 `effectiveAppearance` 调整底色不透明度 |

验收：设置里切换样式立即生效；两种样式在明暗菜单栏下都清晰；专注与休息状态可显示。

### 阶段 3：FocusEngine 与 FocusStore（纯逻辑）

规格见 DESIGN-v7-focus 第 3 节与 DESIGN-SPEC 4.3。

| 项 | 做法 |
|---|---|
| `FocusEngine` | 状态：`idle`、`focusing`、`focusPaused`、`breakWaiting`、`breaking`、`longBreakWaiting`、`longBreaking`。事件：`start`、`pause`、`resume`、`reset`、`skipBreak`、`tick`。输入时间由外部注入（`Date` 参数），不直接读系统时间，便于单测。休息中不可暂停 |
| 时长 | 专注、短休息、长休息可配置，默认 25、5、15 分钟，每轮 4 节。第 4 节之后进入长休息 |
| 自动开始 | 两个开关（专注结束后自动开始休息、休息结束后自动开始下一轮），默认关。关闭时在结束处停下，等点击 |
| 合盖 | 合盖、睡眠、锁屏期间继续计时。合盖超过 15 分钟，删除这 15 分钟，本次专注在合盖那一刻结束。15 分钟写成常量，不放进设置。使用 `NSWorkspace` 的睡眠与唤醒通知（`SystemBridges.swift` 已有桥接） |
| 不做心跳 | 本地只存“当前块开始时间”和“上次已知时间”，意外退出后按保守规则补记 |
| `FocusStore` | JSON 文件，放 `~/Library/Application Support/<bundle id>/focus.json`。记录每个专注块：开始、结束、时长、是否完整。休息不计入统计 |
| 常亮 | 专注进行中用 `ProcessInfo.beginActivity(options: .idleDisplaySleepDisabled)`（或 IOKit 断言），休息和空闲释放。受设置开关控制 |
| 单测 | 引擎不依赖 UI。新增 `Package.swift`（只含引擎、存储与时间格式文件的测试目标）或一个 `swiftc` 测试脚本，覆盖状态流转、休息不可暂停、合盖超过与不超过 15 分钟、意外退出补记、长休息触发 |

验收：单测全部通过，覆盖上面的情形；引擎文件不 `import SwiftUI`。

### 阶段 4：FlowCard 与卡片叠

规格见 DESIGN-SPEC 3.2 与 3.3 的 FlowCard，原型 `docs/prototypes/Flow-Card-v78.dc.html`、`flow-*.png`。

| 项 | 做法 |
|---|---|
| `FlowCard` | 新视图，与 `EventCard`（现 `EventCard`）共用骨架。标题、大数字、进度填充、底行。专注与休息、长休息三种变体，状态与按钮见 DESIGN-SPEC 3.3 的按钮表 |
| 底行 | 左：`CycleDots`（圆点 8，当前节 26，间距 6），其后重置与统计两个图标按钮（热区 28，间距与点组一致）。空闲时四个点一样大，进行中一个点拉长，图标跟着右移。右：主按钮 92×32，距右下各 12 |
| 按钮 | `Start`、`Resume` 绿（`DS.Color.focus` 55%），`Pause` 与 `Skip` 为透明灰（白 12%）。休息等待时 `Skip`（64×32）在 `Start` 左边，间距 8。休息中只有 `Skip`，没有暂停 |
| 休息卡文案 | 标题轮换：Take a Break、Go for a Walk、Look Into the Distance、Stretch Your Legs、Step Away from the Screen。长休息固定 Take a Long Break |
| 进度填充 | 专注随已用时间增长，休息随剩余时间收缩（见默认决定） |
| 卡片叠 | Flow 卡默认在最底层。展开后可拖动任意卡片重新排序，顺序持久化到 `SettingsStore`。收起态后卡露出条显示名称与倒计时 |
| 重置 | 回到 `idle`，四个点清零，不删除已记录的专注 |
| 统计图标 | 点击打开统计窗口（阶段 6 完成前先打开占位） |

验收：按 `flow-*.png` 逐状态比对；拖动排序后重启仍保持；按钮位置与同心圆角正确；休息中无法暂停。

### 阶段 5：QuickPill 浮窗

规格见 DESIGN-SPEC 3.3 的 QuickPill，原型的浮窗行为见 `flow-collapsed.png`、`flow-collapsed-hover.png`、`flow-expanded-*.png`。

| 项 | 做法 |
|---|---|
| 收起态 | 顶牌右上角一个 34 的圆，显示 `chevron.left`。位置：卡顶向下 14，距卡右边 18 |
| 悬停 | 圆向左展开成图标条，箭头淡出、齿轮淡入，0.3s |
| 整叠展开 | 浮窗移到整叠右上角，顶端对齐收起时第一张卡的顶端，右边与卡片右边对齐，常显图标条。整叠整体下移 46（`DS.stackShift`）。两个动作同步，用 `DS.motion` |
| 图标 | 专注入口、统计、日历、设置。顺序与热区见规范 |
| 约束 | 卡片右上角不放任何内容。浮窗层级高于卡片（z 200） |

验收：收起、悬停、展开三态的位置与动画与画布一致；Flow 卡拖到最上面时，浮窗与卡片内容不重叠。

### 阶段 6：统计窗口

规格见 DESIGN-SPEC 3.3 的 StatsWindow，原型 `docs/prototypes/Stats-Window-v78.dc.html`、`stats-week.png`。

| 项 | 做法 |
|---|---|
| 窗口 | 标准窗口，可缩放，默认 560×660，与设置窗口共用激活策略逻辑 |
| 数据 | 从 `FocusStore` 聚合。日按小时 24 柱，周 7 柱，月按日，年 12 柱。只统计专注时间，不显示个数，不分类 |
| 控件 | 指标下拉（总时长、日均时长）、日 / 周 / 月 / 年、日期翻页（下一页在当前周期时置灰）、变化徽章（对比上一周期） |
| 图表 | 使用 Swift Charts 的 `BarMark`（圆头）或自绘。3 条横线，右侧刻度，刻度取“友好步长”表。悬停显示具体时间 |
| 周起始 | 跟随系统区域设置 |

验收：切换周期、翻页、悬停都正确；空数据的周期显示空图表与 0 分钟；与 `stats-week.png` 的版式一致。

### 阶段 7：专注写入日历（EventKit）

规格见 DESIGN-v7-focus 第 4 节。

| 项 | 做法 |
|---|---|
| 权限 | 需要完整访问。更新 `Info.plist` 的 `NSCalendarsFullAccessUsageDescription` 与 README 的权限说明（中英文都要更新） |
| 写入 | 每个专注块完成时写入一个事件，`availability = .free`，带标记。目标日历默认新建“专注”日历，也可选已有日历 |
| 防回环 | 读取日历构建倒计时卡时，按标记过滤掉自己写入的事件 |
| 设置 | 专注页的“把专注写入日历”与“写入的日历” |
| 实测 | 在 Google 账号下新建日历是否可行，Notion Calendar 读取路径，结果写回 `DESIGN-v7-focus.md` 第 4 节 |

验收：专注块出现在系统日历里且显示为空闲；倒计时卡不会出现这些事件。

### 阶段 8：收尾

| 项 | 做法 |
|---|---|
| 通知 | 专注或休息结束时发系统通知与提示音（见默认决定），设置里可关 |
| 无障碍 | 图标按钮 `accessibilityLabel`，减弱动态效果时缩短或关闭位移动画 |
| 文案 | 所有新增文案走 `L()`，补中英文 |
| 文档 | 更新 README（中英）、`docs/DESIGN-SPEC.md` 里与实现有出入的数值 |
| 命名整理 | 按 DESIGN-SPEC 5.2，`EventCard` 改名 `EventCard`，`EventCard.swift` 改 `EventCard.swift` |
| 版本 | 升到 1.2.0，更新 Cask 前先问本人 |

## 3. 默认决定（用户尚未回答的未决问题）

按下面的默认值执行，最终汇报里列出，本人可随时改。

| 编号 | 问题 | 默认 |
|---|---|---|
| 1 | 浮窗最左图标 | 保留，含义为“定位 Flow 卡”：整叠展开并让 Flow 卡高亮闪一下。待本人确认是否去掉 |
| 2 | 休息进度方向 | 休息随剩余时间收缩，专注随已用时间增长 |
| 3 | 结束通知 | 专注与休息结束发系统通知（默认提示音），设置里加开关，默认开 |
| 4 | 长休息之后 | 回到 `idle`，等点击开始下一轮 |
| 5 | 合盖阈值 | 固定 15 分钟，不放进设置 |
| 6 | 卡片顺序持久化 | 是 |
| 7 | 周起始日与跨午夜 | 周起始跟随系统区域。专注块按开始时间归日 |
| 8 | 统计“最近记录”列表 | 不做 |
| 9 | 空闲时菜单栏显示下一个日程 | 默认开 |
| 10 | 全局快捷键 | 不做 |
| 11 | 窗口打开时的 Dock 图标 | 打开设置或统计窗口时显示，全部关闭后隐藏 |
| 12 | 窗口位置与大小记忆 | 是 |
| 13 | 徽标对比度 | 随明暗菜单栏调整底色不透明度 |
| 14 | 默认菜单栏样式 | 圆环 |
| 18 | 本地存储 | JSON 文件 |
| 19 | 5 个未提交改动 | 保留并提交，`peek` 改为 21 |

编号对应 `docs/DESIGN-v7-focus.md` 第 10 节。第 15、16、17 项在阶段 7 里处理，第 20 项（开发代号与 bundle id）暂不动，第 21 项在阶段 8，第 22 项在阶段 3，第 23、24 项在阶段 8。

## 4. 汇报格式

每个阶段结束后用中文汇报：做了什么、改了哪些文件、怎么验证的、与设计不一致的地方、需要本人决定的事。全部完成后给出一份“默认决定使用情况”清单。不要推送，不要改 Cask，不要发布版本。

## 5. 启动方式

在仓库根目录运行 Claude Code，第一句话可以是：

> 阅读 CLAUDE.md 和 docs/HANDOFF.md，从阶段 0 开始执行，每个阶段结束后汇报并等我确认再进入下一阶段。
