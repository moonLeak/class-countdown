# ClassCountdown 项目说明（给 Claude Code）

macOS 26 及以上的菜单栏 App，日历事件倒计时，正在加入番茄钟式的 Flow 专注功能、统计窗口和正规设置窗口。

## 必读文档（按顺序）

1. `docs/HANDOFF.md`：本次交接的任务、顺序、验收标准、默认决定
2. `docs/DESIGN-SPEC.md`：设计令牌、元件、层级、命名标准
3. `docs/DESIGN-v7-focus.md`：需求与规格（状态机、记录规则、日历写入）。第 9 节是决定记录，第 10 节是待确认清单
4. `docs/prototypes/`：v7.8 画布原型的截图与源文件，数值以 HTML 源文件和 DESIGN-SPEC 为准

## 工作规则

- 回复用中文，技术术语附英文。
- 不要执行 `git push`，推送由本人完成。提交可以做，一件事一个提交，提交信息用中文，格式 `feat:`、`fix:`、`chore:`、`docs:`。
- 如果 `.git/*.lock` 残留，运行 `rm -f .git/*.lock` 再继续。
- 本机构建验证命令：`pkill -x ClassCountdown; sleep 1; ./build.sh && open build/ClassCountdown.app`。`build.sh` 用 `swiftc` 编译 `Sources/*.swift`（平铺，不含子目录），目标 `arm64-apple-macos26.0`。新增文件放在 `Sources/` 下，不要建子目录，除非同时改 `build.sh`。
- 代码、注释、文案里不使用长破折号字符，也不写 A 否定后接 B 的对比句式（例如“不是A，而是B”）。
- 所有视觉数值取自 `DesignTokens.swift` 的 `DS`，新增数值先加到 `DS`，再使用。命名遵循 `docs/DESIGN-SPEC.md` 第 5 节。
- 未决问题在 `docs/HANDOFF.md` 里已给出默认决定，按默认执行，并在最终汇报里列出你采用了哪些默认值。遇到清单之外的新分歧，先问本人。
