# 设计规范与命名标准

版本：v1.0（对应设计画布 v7.8）
日期：2026-10-02
画布：https://claude.ai/artifact/R451PwaxXLoKW7kgQaWYCG
平台：macOS 26 及以上，SwiftUI 加 AppKit，Liquid Glass 材质。
状态：设计规范。代码尚未按本规范改动，改动需本人确认后开始。

本文规定四件事：设计令牌（Tokens）、元件（Components）、层级（Hierarchy）、命名（Naming）。画布、设计文档、Swift 代码三处使用同一套名字，改一处必须同步另外两处。

## 1. 原则

1. 同一规则用到底。卡片、按钮、浮窗的圆角、间距、字号全部来自令牌表，不单独写数值。
2. 同心圆角。内层元素贴着外层圆角时，内边距 = 外层圆角半径 − 内层圆角半径。卡片圆角 28，高 32 的全圆角按钮半径 16，所以按钮距卡片右边和下边各 12。
3. 作用域跟着对象走。App 级的东西（设置、日历、统计入口）放浮窗和设置窗口，对象级的操作（开始、暂停、重置、跳过）放卡片上。
4. 卡片右上角永远留空，给浮窗使用。
5. 信息分层靠明暗，不靠颜色。主文字 100%，次级 72%，辅助 52%，更弱 45%。颜色只表达状态和日历归属。
6. 只展示时间，不展示进度百分比，不按分类统计。
7. 所有可交互元素都有悬停态，所有状态切换都有过渡。

## 2. 设计令牌（Tokens）

代码里已有 `DS` 枚举，左列是令牌名，括号是代码当前值与本规范值不一致的地方。

### 2.1 尺寸与间距

| 令牌 | 值 | 说明 |
|---|---|---|
| `DS.cardW` | 340 | 卡片宽 |
| `DS.cardH` | 160 | 卡片高 |
| `DS.radius` | 28 | 卡片圆角 |
| `DS.padX` | 22 | 卡片左右内边距，文字对齐线 |
| `DS.padY` | 18 | 卡片上内边距，标题行 |
| `DS.gap` | 10 | 展开后卡片间距 |
| `DS.peek` | 21 | 收起时后卡露出的高度 |
| `DS.shrink` | 0.04 | 收起时每深一层缩小的比例 |
| `DS.insetConcentric` | 12 | 按钮距卡片右、下边的距离 = 28 − 16 |
| `DS.rowCenter` | 28 | 底行中心线距卡片底边，按钮、四个点、图标共用 |
| `DS.pillH` | 34 | 浮窗高度，全圆角 |
| `DS.pillGap` | 12 | 展开后浮窗与第一张卡的间距 |
| `DS.stackShift` | 46 | 展开后整叠下移量 = pillH + pillGap |

### 2.2 字体

| 令牌 | 字号 / 字重 | 用途 |
|---|---|---|
| `DS.fDisplay` | 54 / Medium(500)，等宽数字，字距 −0.04em | 卡片大数字 |
| `DS.fBody` | 13 / Semibold(590) | 卡片标题、行标题 |
| `DS.fCaption` | 11 / Regular(400)，等宽数字 | 时间段、说明 |
| `DS.fButton` | 12 / Semibold(590) | 按钮文字 |
| `DS.fNumeral` | 60 / Semibold(600)，字距 −0.04em | 统计页总量 |
| `DS.fMenubar` | 13 / Medium(500)，等宽数字 | 菜单栏文字 |

### 2.3 文字明暗

| 令牌 | 不透明度 | 用途 |
|---|---|---|
| `DS.l1` | 100% | 倒计时数字 |
| `DS.l2` | 72% | 卡片标题 |
| `DS.l3` | 52% | 时间段、说明、露出条右侧倒计时 |
| `DS.l4` | 45% | 分组标题、脚注 |

### 2.4 颜色

| 令牌 | 值 | 用途 |
|---|---|---|
| `DS.Color.focus` | rgb(48,209,88) #30D158 | 专注与休息，统一用绿色 |
| `DS.Color.warn` | rgb(255,159,10) #FF9F0A | 日程临近结束 |
| `DS.Color.danger` | rgb(255,69,58) #FF453A | 退出等破坏性操作 |
| `DS.Color.eventDefault` | rgb(10,132,255) #0A84FF | 日历没有颜色时的兜底 |
| 日历色 | `EKCalendar.cgColor` | 事件卡的进度填充色 |
| 统计柱 | 渐变 rgb(122,214,168) 到 rgb(52,150,112) | 统计页柱体 |
| 涨 / 跌 | #7BE0AD / #FF9A8F | 变化徽章 |

进度填充：顶部 34%、底部 20%，右边缘线 55%。临近结束：顶部 52%、底部 34%、边缘 88%，并换成警示色。

### 2.5 材质（Liquid Glass）

| 令牌 | 配方 |
|---|---|
| `DS.Glass.card` | 背景白 10%，背景模糊 24，饱和度 180%，内高光 `inset 0 1px 0 白30%`，内描边 0.5pt 白 16%，外阴影 `0 10 28 黑40%`（越靠后越浅，每层减 8%） |
| `DS.Glass.window` | 背景 rgba(34,38,52,0.80)，模糊 30，圆角 26，外阴影 `0 24 60 黑50%` |
| `DS.Glass.pill` | 背景白 20%，模糊 20，内高光白 40%，外阴影 `0 4 14 黑25%` |
| `DS.Glass.group` | 背景白 7%，内描边 0.5pt 白 10%，圆角 14 |
| `DS.Glass.popup` | 背景 rgba(52,58,74,0.96)，圆角 12，内描边白 18% |

**实现按 Apple 的 Liquid Glass 规范，不照搬上表的 CSS 配方：**

| 规则 | 做法 |
|---|---|
| 玻璃只用在浮在内容之上的对象 | 卡片、浮窗、卡片里的按钮用 `glassEffect`；窗口里的内容、列表、图表不用玻璃 |
| 卡片背景透明，颜色只在内容上 | 用 `clear` 玻璃，下面垫一层黑色暗层，浓度由设置里的“卡片透明度”滑块决定（`DS.cardDimMax` 0.60 到 `DS.cardDimMin` 0.15，默认滑块 0.4）。日历色、专注绿、警示橙只出现在进度填充、图案和按钮上。面板按深色外观画，白字 |
| 可交互的玻璃加 `interactive()` | 卡片、按钮、浮窗，指针与按压有镜面反应 |
| 相邻的玻璃放进 `GlassEffectContainer` | 专注卡的 Skip 与 Start 靠得近时自然融合 |
| `clear` 的代价 | `clear` 几乎不模糊，压在繁忙内容上文字会读不清，所以暗层有下限，用户可以往“实”滑 |
| 同心圆角 | 按钮半径 = 卡片半径 − 距边距离（28 − 12 = 16） |
| 系统控件 | 设置与统计窗口用标准窗口、工具栏、分段控件、菜单，macOS 26 自动带玻璃 |

### 2.6 动效

| 令牌 | 值 | 用途 |
|---|---|---|
| `DS.motion` | 0.42s，曲线 (0.32, 0.72, 0, 1) | 卡片位移、缩放、浮窗移动 |
| `DS.fade` | 0.3s ease-in-out | 文字与按钮透明度 |
| `DS.pillWidth` | 0.3s，同曲线 | 浮窗展开收起 |
| `DS.toggle` | 0.2s ease | 开关、悬停 |
| `DS.bar` | 0.38s，同曲线 | 统计柱高度与位置 |
| `DS.press` | 0.14s，缩放 0.972 | 卡片按压 |

### 2.7 图标

SF Symbols，描边 1.8，常规尺寸 15，工具栏标签 20。

| 用途 | 符号 |
|---|---|
| 设置 | `gearshape` |
| 日历 | `calendar` |
| 统计 | `chart.bar` |
| 专注入口 | `scope`（待定，见未决问题） |
| 重置 | `arrow.counterclockwise` |
| 开始 | `play.fill` |
| 暂停 | `pause.fill` |
| 浮窗收起 | `chevron.left` |
| 日期翻页 | `chevron.left` / `chevron.right` |

## 3. 元件（Components）

编号规则 `C-<层>.<序号>`：层 3 为容器，层 4 为元件，层 5 为元素。

### 3.1 容器

| 编号 | 名称 | 说明 | 代码 |
|---|---|---|---|
| C-3.1 | `CardStack` | 卡片叠。收起时只露最前一张加后卡露出条，展开后纵向铺开，可拖动排序，Flow 卡默认在最底 | `CardStack.swift` |
| C-3.2 | `QuickPill` | 系统级浮窗。收起时是顶牌右上角的一个圆（显示向左箭头），悬停展开成图标条（齿轮出现）。展开整叠后移到整体右上角，顶端对齐收起时第一张卡的顶端 | 新增 |
| C-3.3 | `SettingsWindow` | 正规 App 窗口，可缩放，工具栏标签：通用、日历、专注、关于 | 新增 |
| C-3.4 | `StatsWindow` | 统计窗口，日 / 周 / 月 / 年 | 新增 |
| C-3.5 | `MenuBarItem` | 菜单栏项，两种样式：`ring` 圆环、`badge` 徽标 | `PanelController` 与 `RingIcon` |
| C-3.6 | `FormGroup` | 设置里的一组行，圆角 14，行高最小 40，行间 0.5pt 分隔线 | 新增 |

### 3.2 元件

| 编号 | 名称 | 变体 | 状态 |
|---|---|---|---|
| C-4.1 | `EventCard` | 无 | `upcoming`、`running`、`warning` |
| C-4.2 | `FlowCard` | `focus`、`break`、`longBreak` | `idle`、`focusing`、`focusPaused`、`breakWaiting`、`breaking` |
| C-4.3 | `GlassButton` | `primary`（绿 55%）、`ghost`（白 12%）、`danger` | `default`、`hover`、`pressed`、`disabled` |
| C-4.4 | `IconButton` | 无 | `default`、`hover` |
| C-4.5 | `CycleDots` | 无 | 四个点，每个 `done`、`current`、`todo` |
| C-4.6 | `ToggleRow` | 无 | `on`、`off` |
| C-4.7 | `MenuRow` | 无 | `closed`、`open` |
| C-4.8 | `StepperRow` | 无 | 值加减，带上下限 |
| C-4.9 | `SegmentedRow` | 无 | 二到四项 |
| C-4.10 | `CalendarRow` | 无 | 圆点色加开关 |
| C-4.11 | `MetricChip` | 无 | `closed`、`open` |
| C-4.12 | `PeriodSwitcher` | `D`、`W`、`M`、`Y` | 四选一 |
| C-4.13 | `DeltaBadge` | `up`、`down`、`none` | 无 |
| C-4.14 | `RangeNavigator` | 无 | 下一页在当前周期时置灰 |
| C-4.15 | `TimeBarChart` | `day`、`week`、`month`、`year` | `idle`、`hover` |
| C-4.16 | `Tooltip` | 无 | 无 |

### 3.3 元素与关键规格

**EventCard 与 FlowCard 共用骨架**

| 元素 | 位置与规格 |
|---|---|
| `Title` | 左 22，上 18，13/590，72% |
| `Time` | 左 22，垂直居中，54/500 |
| `ProgressFill` | 左起，宽 = 进度，渐变 34% 到 20%，右边缘线 1pt |
| `StripTitle` / `StripTime` | 收起后卡的露出条，左右各 22，高 = `peek / (1 − shrink × i)`，右侧显示倒计时，不显示百分比 |
| `Range`（仅 EventCard） | 左 22，底行，11，52%，显示起止时间 |

**FlowCard 底行（中心线距底 28）**

| 元素 | 规格 |
|---|---|
| `CycleDots` | 左 22，圆点 8，当前节 26，间距 6，已完成 85%，当前 35%，未到 22% |
| `ResetButton` | `IconButton`，点组之后，点组与图标、图标与图标之间的视觉间距相等（约 13） |
| `StatsButton` | 同上，紧随 `ResetButton` |
| `PrimaryButton` | 右 12，下 12，92×32，半径 16，12/590 |
| `SkipButton` | 仅 `breakWaiting`，在主按钮左侧，间距 8，64×32，`ghost` |

空闲态四个点一样大，图标靠左。进行中有一个点拉长，图标随之右移，间距不变。

**FlowCard 按钮表**

| 状态 | 主按钮 | 次按钮 |
|---|---|---|
| `idle` | `Start`（绿，播放图标） | 无 |
| `focusing` | `Pause`（`ghost`，暂停图标） | 无 |
| `focusPaused` | `Resume`（绿，播放图标） | 无 |
| `breakWaiting` | `Start`（绿，播放图标） | `Skip`（`ghost`） |
| `breaking` | `Skip`（`ghost`，无图标） | 无 |

休息中不可暂停，所以主按钮直接是 `Skip`。

**QuickPill 规格**

| 项 | 规格 |
|---|---|
| 展开态 | 高 34，半径 17，图标热区 30，图标 15，顺序：专注入口、统计、日历、设置 |
| 收起态 | 34 的圆，显示 `chevron.left`（17，描边 2），位置：卡顶向下 14，距卡右边 18 |
| 悬停 | 收起圆向左展开为图标条，箭头淡出、齿轮淡入，0.3s |
| 整叠展开 | 浮窗移到整叠右上角，顶端对齐收起时第一张卡的顶端，右边与卡片右边对齐，常显图标条；整叠下移 46 |
| 图标分工 | 绿框内为 App 快捷操作（专注入口、统计、日历，后续可加“新增日程”），齿轮为 App 设置 |

**SettingsWindow 规格**

| 项 | 规格 |
|---|---|
| 默认尺寸 | 540×600，最小 420×380，可缩放，内容区随窗口伸缩并滚动 |
| 标题栏 | 红黄绿，窗口标题为当前标签名 |
| 工具栏标签 | 通用、日历、专注、关于，图标 20 加文字 10.5，选中态白 14% 圆角底 |
| 内容区 | 最大宽 560 居中，分组标题 11/590 45%，组与组间距 18 |
| 行 | 左标题 13，可带 11 的说明，右侧控件。开关 38×22；菜单为胶囊按钮加弹出列表；步进器带数值与加减 |

**StatsWindow 规格**

| 项 | 规格 |
|---|---|
| 尺寸 | 560×660 |
| 第一行 | 左 `MetricChip`（总时长、日均时长），右 `PeriodSwitcher` |
| 第二行 | 左总量（60/600，单位 16）与 `DeltaBadge`，右 `RangeNavigator` |
| 图表 | 3 条横线，刻度在右侧，圆头柱，柱宽 = 槽宽 × 0.66（上限 52），渐变绿，悬停时其他柱降到 55%，出现 `Tooltip` |
| 刻度 | 取最小的“友好步长”使 3 × 步长 ≥ 最大值：0.25、0.5、1、2、3、4、5、6、8、10、12、15、20、25、30、40、50…，小于 1 小时显示分钟 |
| 内容 | 只统计时间。不显示 Flow 个数，不按分类拆分 |

**MenuBarItem 规格**

| 样式 | 规格 |
|---|---|
| `ring` | 16pt 模板图像，轨道 28% 不透明，进度弧从 12 点顺时针，2.2 线宽，圆头 |
| `badge` | 高 20，圆角 6，左右内边距 8，13/500 白字带暗阴影。底色 = 状态色 40%，进度填充 = 状态色 90%（可关，关后为纯色） |
| 状态色 | 日程倒计时用日历色，临近结束橙，专注与休息绿，空闲（下一个日程）灰 |
| 显示内容 | 仅图标、仅剩余时间、名称与剩余时间 |

## 4. 层级（Hierarchy）

### 4.1 结构层

| 层 | 名称 | 内容 |
|---|---|---|
| L0 | App | `TimeTool` |
| L1 | 界面（Surface） | `Panel`（点菜单栏出现的卡片面板）、`SettingsWindow`、`StatsWindow`、`MenuBarItem`、`ContextMenu` |
| L2 | 容器（Container） | `CardStack`、`QuickPill`、`FormGroup`、`ToolbarTabs` |
| L3 | 元件（Component） | `EventCard`、`FlowCard`、`GlassButton`、`ToggleRow` 等，见 3.2 |
| L4 | 元素（Element） | `Title`、`Time`、`ProgressFill`、`CycleDots`、图标 |

画布文件按 L1 到 L3 命名，元件内部的元素按 L4 命名。

### 4.2 叠放顺序（z）

| 值 | 内容 |
|---|---|
| 0 | 背景 |
| n − i | 第 i 张卡（n 为卡数，越靠前越高） |
| 60 | 正在拖动的卡（放大 1.02，阴影 55%） |
| 200 | `QuickPill` |
| 300 | 弹出菜单、下拉列表 |
| 400 | `Tooltip`、提示 |

窗口（设置、统计）是独立 NSWindow，不参与上表。

### 4.3 状态机命名

Flow 状态与代码保持一致：`idle`、`focusing`、`focusPaused`、`breakWaiting`、`breaking`、`longBreakWaiting`、`longBreaking`。画布原型中的 `focus`、`breakWait`、`breakRun` 是同一状态的简写。

## 5. 命名标准

### 5.1 通用规则

1. 英文名用 PascalCase（类型、元件），属性与变量用 camelCase，令牌用 `DS.<类别><名称>`。
2. 同一个东西只有一个名字。设计稿、文档、代码、文案 key 都用同一个词。
3. 状态与变体不写进元件名。写成 `FlowCard[state=focusing]`、`GlassButton{variant=ghost}`。
4. 不用缩写，除非是表里已列出的（`DS`、`L1`）。
5. 中文名只用于画布标题和文档说明，不进代码。

### 5.2 元件与代码对应

| 设计名 | Swift 类型 / 文件 | 现状 |
|---|---|---|
| `EventCard` | `EventCard.swift`，原名 `CountdownCard` | 已改名 |
| `FlowCard` | `FlowCard.swift` | 已实现 |
| `CardStack` | `CardStack.swift` | 已有 |
| `QuickPill` | `QuickPill.swift` | 已实现 |
| `SettingsWindow` | `SettingsWindowController.swift` | 已改为标准窗口 |
| `StatsWindow` | `StatsWindowController.swift` | 已实现 |
| `RingIcon` | `RingIcon.swift` | 已有 |
| `BadgeIcon` | `BadgeIcon.swift` | 已实现 |
| `GlassButton`、`IconButton` | `GlassButton.swift` 等（保持 Sources 下平铺，见交接文档） | 新增 |
| `FocusEngine` | `FocusEngine.swift` | 已实现，纯逻辑，有单测 |
| `FocusStore` | `FocusStore.swift` | 已实现，JSON 文件 |

### 5.3 令牌、事件、文案 key

| 类型 | 规则 | 例子 |
|---|---|---|
| 令牌 | `DS.<类别><名称>`，颜色放 `DS.Color`，材质放 `DS.Glass` | `DS.cardW`、`DS.Color.focus` |
| 用户操作回调 | `on<元件><动作>` | `onPrimaryTap`、`onResetTap` |
| 状态枚举 | 动词进行式或形容词 | `focusing`、`breakWaiting` |
| 文案 key | `<区域>.<元件>.<项>`，全小写加点 | `flow.button.start`、`settings.focus.autoBreak` |
| 资源 | `<类型>.<名称>` | `icon.reset` |
| 设置存储 key | `<区域>.<名称>`，camelCase | `focus.shortBreakMinutes`、`menubar.style` |

### 5.4 画布文件命名

格式：`<区域>-<主题>[-<变体>]-v<主版本><次版本>.dc.html`。

| 区域 | 例 |
|---|---|
| `Panel` | `Panel-Stack-v78` |
| `Flow` | `Flow-Card-v78` |
| `Pill` | `Pill-Behavior-B1-v72` |
| `Stats` | `Stats-Window-v78` |
| `MenuBar` | `MenuBar-Styles-v78` |
| `Settings` | `Settings-Window-v78` |

规则：版本号去掉小数点（7.8 写 v78）。每次迭代复制成新版本放在新的图层，不覆盖旧版。用户自己编辑的板子除外。已有板子保持旧名，只对新增板子执行本规则。

### 5.5 画布图层与标注

| 项 | 规则 |
|---|---|
| 节标题 | `title1`，格式 `v7.8 · 主题`，写在该节第一行上方 |
| 说明便签 | 默认色，写做了什么 |
| 决定便签 | purple，写结论 |
| 注意便签 | green，写与代码或文档的差异 |
| 排布 | 每节一行，板与板间距 80，节与节间距 140，v7 之前的版本保持原样 |
| 可玩的板 | 标记 `is_interactive`，板底部写操作提示 |

### 5.6 文案与术语

| 中文 | 英文界面文案 | 备注 |
|---|---|---|
| 专注 | Focus | 卡片标题 |
| 休息 | Take a Break | 休息卡标题，提示语轮换见设计文档 5.1.1 |
| 长休息 | Take a Long Break | 第 4 节之后 |
| 开始 | Start | 绿色主按钮 |
| 暂停 | Pause | 仅专注中 |
| 继续 | Resume | 暂停后 |
| 跳过 | Skip | 休息卡，休息中是唯一按钮 |
| 重置 | Reset | 图标按钮的无障碍标签 |
| 统计 | Statistics | 窗口标题 |
| 总时长 / 日均时长 | Total Time / Daily Average | 指标下拉 |

时间格式：倒计时 `mm:ss`，超过 1 小时 `h:mm:ss`，统计总量 `X 小时 Y 分`（英文 `Xh Ym`）。

## 6. 交互规范

1. 点卡片：展开或收起。展开后拖动卡片重新排序，顺序持久化。
2. 点浮窗图标：专注入口、统计窗口、日历 App、设置窗口。
3. 右键菜单栏图标：打开日历、设置、关于、退出。
4. 休息中不可暂停。休息卡等待开始时可点 `Start` 或 `Skip`。
5. 专注或休息结束后停下，等点击进入下一步，除非对应的自动开始开关打开。
6. 重置：回到 `idle`，本轮四个点清零，不删除已记录的专注。
7. 设置窗口是普通窗口：点其他地方不会消失，可缩放，可最小化，快捷键 Command+逗号打开。

## 7. 与 Apple 设计规范的对应

| 规范点 | 本设计的做法 |
|---|---|
| 同心圆角（Concentric） | 按钮与卡片圆角同心，内边距 12 |
| 标准窗口 | 设置与统计使用 `NSWindow`，带红黄绿，可缩放，不使用 popover 做设置 |
| 设置窗口用工具栏标签 | 四个分区，使用工具栏标签，不使用侧边栏 |
| 层级靠材质与明暗 | Liquid Glass 材质，文字四级明暗 |
| 菜单栏图标 | 圆环为模板图像，自动适配明暗；徽标为彩色图像，需要在明暗两种菜单栏下检查对比 |
| 点击目标 | 图标按钮热区 28，浮窗图标热区 30 |
| 动效 | 统一曲线，尊重系统“减弱动态效果” |
| 无障碍 | 所有图标按钮提供 `accessibilityLabel`，数字使用等宽数字 |

## 8. 画布索引（v7.8）

| 板 | 内容 |
|---|---|
| `Flow-StatsC-v78` | Flow 卡片定稿样式，休息中只留 Skip，浮窗收起显示向左箭头 |
| `Stats-v78` | 统计窗口，只统计时间，可操作 |
| `MenuBar-v78` | 圆环与徽标两种样式，可切换状态与显示内容 |
| `Settings-v78` | 设置窗口，可缩放，四个标签，控件可操作 |

## 9. 实现与规范的出入（v1.2.0）

| 项 | 规范 | 实现 | 原因 |
|---|---|---|---|
| 设置窗口材质 | `DS.Glass.window` 半透明 | 系统标准的不透明窗口背景 | 透明窗口在缩放时标题栏与工具栏重绘不全 |
| 卡片拖动排序 | 任意卡片可拖 | 只有 Flow 卡可拖，位置记在 `cards.flowSlot` | 日程卡的顺序由结束时间决定，手动排没有意义 |
| 浮窗最左图标 | 待定 | 保留，含义为定位 Flow 卡：展开整叠并让它的边框亮一下 | 默认决定 1 |
| 菜单栏徽标“仅图标” | 三种显示内容 | 只有“名称与剩余时间”“仅剩余时间”两种 | 徽标里没有文字时是一个空色块，没有意义 |
| 意外退出补记 | 不做心跳 | 只在状态变化、睡眠和退出时存快照 | 与规范一致。强杀或断电时可能少记最后一段 |
| 统计的日视图 | 按小时分柱 | 专注块按开始时间归入小时与日，跨整点或跨午夜的块不拆分 | 默认决定 7 |
| “同时记录休息” | 设置项，默认关 | 未实现 | 休息不计入统计，也没有需求 |
| 菜单栏圆环颜色 | 状态色 | 模板图像，跟随菜单栏明暗 | 圆环是模板图像，不带色 |
