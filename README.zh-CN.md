# TimeTool

[English](README.md) · **简体中文**

macOS 菜单栏小工具。读你的日历，显示**当前这件事还剩多久结束**。

上课、开会、做实验的时候，你想知道的从来不是「几点到几点」，
而是「还有多久」。这个工具就做这一件事。

菜单栏常驻一行 `EK 210 Lab · 23:47`，点开是一张方卡，
背景是一条走满就结束的横向进度条。

---

## 系统要求

macOS 26 或更高版本。卡片材质用的是系统的 Liquid Glass，更早的系统上没有这个效果。

## 安装

### 方式一：下载 DMG（推荐给所有人）

1. 去 [Releases](../../releases/latest) 下载最新的 `TimeTool-x.y.z.dmg`
2. 双击打开，把应用拖进「应用程序」文件夹
3. **第一次打开会被系统拦住**，见下面「为什么打不开」

### 方式二：Homebrew

```bash
brew tap moonLeak/class-countdown https://github.com/moonLeak/class-countdown
brew install --cask --no-quarantine class-countdown
```

`--no-quarantine` 不能省，否则装完打不开。

### 方式三：自己编译

需要 macOS 26 或更高版本，以及 Xcode Command Line Tools：

```bash
git clone https://github.com/moonLeak/class-countdown.git
cd class-countdown
./build.sh && open build/TimeTool.app
```

---

## 为什么打不开

macOS 会拦截没有经过苹果「公证」（notarization）的应用，提示
「无法打开，因为无法验证开发者」或者「已损坏」。

公证需要每年 99 美元的苹果开发者账号。这是个免费小工具，所以没有。
**这不代表应用有问题**，源码就在这个仓库里，你可以自己读、自己编译。

放行方式，任选其一：

**图形界面**：双击打开一次（会报错），然后去
**系统设置 → 隐私与安全性**，往下翻会看到「已阻止 TimeTool」，
点 **仍要打开**。

**命令行**：

```bash
xattr -dr com.apple.quarantine /Applications/TimeTool.app
```

---

## 第一次使用

启动后会请求日历权限（完整访问）。应用读取日程的**标题和起止时间**来计算倒计时，
不联网，不上传，不修改你已有的任何日程。授权后菜单栏立刻出现倒计时。

只有你在设置的「专注」页打开「把专注写入日历」之后，应用才会往日历里**新增**事件：
每完成一段专注，写一个标为「空闲」的事件，默认放进一个新建的「专注」日历。
这些事件带有标记，倒计时不会把它们当成日程。

### Google 日历怎么办

不需要授权 Google，也不需要导入文件。
去 **系统设置 → 互联网账户**，添加你的 Google 账户并勾选「日历」，
系统日历会自动同步，这个应用直接读系统日历就行。

同理，iCloud 日历、学校的 Exchange 日历、任何订阅的 `.ics` 课表，
只要在系统日历里能看到，这里就能用。

### 专注与统计

卡叠最底层有一张**专注卡**，是一个番茄钟：默认专注 25 分钟、短休息 5 分钟、
长休息 15 分钟，每 4 节专注后进入长休息。卡片上有四个圆点表示本轮进度，
右下角按钮随状态变化（开始、暂停、继续、跳过）。休息中不能暂停。

- 合盖、睡眠期间计时继续。合盖超过 15 分钟，本次专注在合盖那一刻结束
- 进程意外退出后，下次启动按上次已知时间保守补记
- 点卡片上的统计图标，或浮窗里的统计图标，打开**统计窗口**：
  日、周、月、年的柱状图，总时长或日均时长，与上一周期对比，可翻页
- 只统计专注时间，不统计休息，不显示个数，不分类
- 记录保存在 `~/Library/Application Support/com.carson.classcountdown/focus.json`

### 设置

右键菜单栏图标或卡片，选「设置…」（也可以按 Command+逗号）。设置是一个标准窗口，
有四个标签：

- **通用**：界面语言（11 种，改完当场生效）、登录时打开；菜单栏的样式（圆环或徽标）、
  显示内容、分隔符、空闲时是否显示下一个日程
- **日历**：勾选哪些日历参与倒计时；全天事件默认不算；临近结束警示（默认 5 分钟）
- **专注**：三种时长、两个自动开始开关、专注时保持屏幕常亮、结束时通知，
  以及「把专注写入日历」和目标日历
- **关于**：版本与退出

### 操作

| 操作 | 结果 |
| --- | --- |
| 点菜单栏图标 | 卡片从图标里长出来，再点一次原路缩回去 |
| 右键菜单栏图标 | 打开日历、设置、关于、退出 |
| 单击卡片 | 展开整叠，再点一次收起 |
| 拖动专注卡（展开后） | 换它在卡叠里的位置，重启后保持 |
| 鼠标移到卡片右上角的小圆 | 展开成图标条：专注、统计、日历、设置 |
| 二段重按卡片（触控板） | 卡片下沉，跳转日历，面板随后收回 |

---

## 它不做什么

- 日程倒计时本身不推送、不响铃，只有专注或休息结束时发一条通知（可关）
- 只记录专注，不记录别的；不做分类，不显示个数
- 不修改、不删除你已有的任何日程（打开「把专注写入日历」后，只会新增自己的专注事件）
- 不联网

---

## 项目结构

| 文件 | 职责 |
| --- | --- |
| `Sources/App.swift` | 入口与 app delegate |
| `Sources/PanelController.swift` | 菜单栏项、透明面板、出场收回动效 |
| `Sources/DesignTokens.swift` | 设计定下的全部数值，以及玻璃材质 |
| `Sources/CalendarService.swift` | EventKit 封装：权限、48 小时窗口拉取、变更监听 |
| `Sources/ScheduleModel.swift` | 状态机：哪些日程正在进行、剩余秒数、进度比例 |
| `Sources/CardStack.swift` | 弹出面板：卡包式堆叠、展开、右键菜单 |
| `Sources/Interaction.swift` | 单击与二段重按，同一个 NSView 接住，只作用于被按的那张卡 |
| `Sources/Localization.swift` | 运行时文案表，11 种语言，切换不用重启 |
| `Sources/AppState.swift` | 各服务的共同持有者 |
| `Sources/EventCard.swift` | 单张 340×160 卡片，只有信息，没有控件 |
| `Sources/TickEngine.swift` | 每秒心跳，只驱动显示刷新 |
| `Sources/SettingsWindowController.swift` | 设置窗口：标准窗口、工具栏标签、记住位置与大小 |
| `Sources/SettingsView.swift` | 设置各标签的内容 |
| `Sources/AppWindowTracker.swift` | 设置与统计窗口打开时切到 regular 激活策略，全部关闭后恢复 |
| `Sources/FlowCard.swift` | 专注卡 |
| `Sources/QuickPill.swift` | 卡片右上角的浮窗 |
| `Sources/GlassButton.swift` | 胶囊按钮、图标按钮、四个点 |
| `Sources/FocusEngine.swift` | 专注状态机，纯逻辑，时间由调用方传入 |
| `Sources/FocusStore.swift` | 专注记录的 JSON 存储与意外退出补记 |
| `Sources/FocusController.swift` | 把引擎接到心跳、睡眠唤醒、存储、常亮、通知与日历 |
| `Sources/FocusCalendarWriter.swift` | 把专注写进日历，带标记 |
| `Sources/FocusCalendarMarker.swift` | 写入日历的专注事件的标记，用来过滤和去重 |
| `Sources/FocusNotifier.swift` | 结束通知 |
| `Sources/ScreenAwake.swift` | 专注时保持屏幕常亮 |
| `Sources/StatsAggregator.swift` | 统计聚合，纯函数 |
| `Sources/StatsView.swift`、`StatsWindowController.swift` | 统计窗口 |
| `Sources/BadgeIcon.swift`、`RingIcon.swift` | 菜单栏徽标与圆环 |
| `Sources/SettingsStore.swift` | 用户偏好的持久化 |
| `Sources/LaunchAtLogin.swift` | 登录时打开 |
| `Sources/SystemBridges.swift` | 休眠唤醒与时区变更通知的小包装 |
| `Sources/TimeFormat.swift` | 倒计时文本格式规则 |
| `build.sh` | 编译并组装 .app |
| `package.sh` | 打包成 .dmg |
| `uninstall.sh` | 卸载应用、偏好设置与登录项 |
| `test.sh` | 跑状态机、存储、统计聚合的单测（`Tests/main.swift`，不需要整个 App） |
| `dev.sh` | 开发用：编译并用 `DevData/mock-events.json` 里的模拟日程启动，不读系统日历 |

### 几个设计决定

**两条独立的刷新链路。** 日历数据变更走 `EKEventStoreChanged` 通知，
加 15 分钟兜底轮询和唤醒重拉；倒计时数字走 `TickEngine`。
混在一起就变成每秒查一次日历了。

**所有时间用 `Date`（UTC 绝对时间点）运算**，只在渲染时转本地时区。
跨时区、夏令时切换都不会算错。

**唤醒后不依赖计时器累加值**，直接用当前时间重算。

**重叠日程取最先结束的那个**，也就是最先把你放走的那件事，
卡片上会标注还有几个重叠。

**重叠日程堆成一叠卡包。** 一个日程就是一张卡，不再把它们压缩成一行小字。
最前面那张完整显示，后面的往下露出 21 点，刚好够读完名称和倒计时。
单击展开收起，右键出应用菜单。

**进度条用日程所属日历的颜色。** 橙色专门留给临近结束的警示，
所以警示除了换色还会提高填充浓度，万一某个日历本身就是橙色，状态变化仍然读得出来。

**重复日程用 `enumerateEvents` 拿展开后的实例**，不自己解析 RRULE。
这是选 EventKit 而不是自己解析 `.ics` 的主要原因。

---

## 路线图

- [ ] iOS / iPadOS 小组件（主屏与负一屏）
- [ ] 手动导入 `.ics` 文件
- [ ] 锁屏实时动态（Live Activity）

---

## License

MIT
