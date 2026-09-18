# ClassCountdown 下课倒计时

[English](README.md) · **简体中文**

macOS 菜单栏小工具。读你的日历，显示**当前这件事还剩多久结束**。

上课、开会、做实验的时候，你想知道的从来不是「几点到几点」，
而是「还有多久」。这个工具就做这一件事。

菜单栏常驻一行 `EK 210 Lab · 23:47`，点开是一张方卡，
背景是一条走满就结束的横向进度条。

---

## 安装

### 方式一：下载 DMG（推荐给所有人）

1. 去 [Releases](../../releases/latest) 下载最新的 `ClassCountdown-x.y.z.dmg`
2. 双击打开，把应用拖进「应用程序」文件夹
3. **第一次打开会被系统拦住**，见下面「为什么打不开」

### 方式二：Homebrew

```bash
brew tap moonLeak/class-countdown https://github.com/moonLeak/class-countdown
brew install --cask --no-quarantine class-countdown
```

`--no-quarantine` 不能省，否则装完打不开。

### 方式三：自己编译

只需要 Xcode Command Line Tools：

```bash
git clone https://github.com/moonLeak/class-countdown.git
cd class-countdown
./build.sh && open build/ClassCountdown.app
```

---

## 为什么打不开

macOS 会拦截没有经过苹果「公证」（notarization）的应用，提示
「无法打开，因为无法验证开发者」或者「已损坏」。

公证需要每年 99 美元的苹果开发者账号。这是个免费小工具，所以没有。
**这不代表应用有问题**，源码就在这个仓库里，你可以自己读、自己编译。

放行方式，任选其一：

**图形界面**：双击打开一次（会报错），然后去
**系统设置 → 隐私与安全性**，往下翻会看到「已阻止 ClassCountdown」，
点 **仍要打开**。

**命令行**：

```bash
xattr -dr com.apple.quarantine /Applications/ClassCountdown.app
```

---

## 第一次使用

启动后会请求日历权限。应用只读取日程的**标题和起止时间**，
不修改任何日程，不联网，不上传。授权后菜单栏立刻出现倒计时。

### Google 日历怎么办

不需要授权 Google，也不需要导入文件。
去 **系统设置 → 互联网账户**，添加你的 Google 账户并勾选「日历」，
系统日历会自动同步，这个应用直接读系统日历就行。

同理，iCloud 日历、学校的 Exchange 日历、任何订阅的 `.ics` 课表，
只要在系统日历里能看到，这里就能用。

### 设置

点菜单栏图标，卡片左下角的齿轮：

- **日历**：勾选哪些日历参与倒计时（比如只要课表，排除生日和节假日）
- **全天事件**：默认不算，否则「生日」会占据一整天
- **警示色**：剩余多久时数字和进度条变色，默认 5 分钟
- **开机自启**

---

## 它不做什么

- 不推送通知，不响铃，不打断你
- 不记录历史，不做时间统计
- 不创建、不修改、不删除任何日程
- 不联网

---

## 项目结构

| 文件 | 职责 |
| --- | --- |
| `Sources/App.swift` | 入口，MenuBarExtra 场景与菜单栏那行文字 |
| `Sources/DesignTokens.swift` | 设计定下的全部数值，以及玻璃材质 |
| `Sources/CalendarService.swift` | EventKit 封装：权限、48 小时窗口拉取、变更监听 |
| `Sources/ScheduleModel.swift` | 状态机：哪些日程正在进行、剩余秒数、进度比例 |
| `Sources/CardStack.swift` | 弹出面板：卡包式堆叠、展开、右键菜单 |
| `Sources/CountdownCard.swift` | 单张 340×160 卡片，只有信息，没有控件 |
| `Sources/ScrollWheel.swift` | 一次滚动手势只换一张卡 |
| `Sources/TickEngine.swift` | 每秒心跳，只驱动显示刷新 |
| `Sources/SettingsView.swift` | 设置面板 |
| `Sources/TimeFormat.swift` | 倒计时文本格式规则 |
| `build.sh` | 编译并组装 .app |
| `package.sh` | 打包成 .dmg |
| `uninstall.sh` | 卸载应用、偏好设置与登录项 |

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
最前面那张完整显示，后面的往下露出 40 点，刚好够读完名称和百分比。
单击展开，滚轮换到下一张，右键出应用菜单。

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
