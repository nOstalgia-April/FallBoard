# FallBoard

**九格之间，一推定局。** 基于 BoardRouge — Push Prototype v0.1 PRD 的 Godot 单人回合制战术原型。

3×3 棋盘，固定 2v2；比接触面的数字，将敌人推出棋盘。没有生命值、旋转、随机属性或成长系统。

![FallBoard 实际游戏画面与攻击预览](https://github.com/nOstalgia-April/FallBoard/releases/latest/download/FallBoard-preview.png)

## 直接试玩

- **Windows**：从 [Releases](https://github.com/nOstalgia-April/FallBoard/releases) 下载 `FallBoard-Windows.zip`，解压后双击 `FallBoard.exe`。不需要安装 Godot。
- **Web**：下载 `FallBoard-Web.zip` 后通过 HTTP 静态服务器打开 `index.html`，不要直接双击 HTML。可在解压目录运行 `python -m http.server 8000`，然后打开 `http://localhost:8000`。Web 导出使用单线程，不需要跨源隔离响应头。
- **Godot 工程**：下载或克隆此仓库，用 **Godot 4.5.1 标准版**导入 `project.godot`，按 **F6/F5** 运行。不要使用 Godot 3。

GitHub Actions 会在 `main` 更新时运行测试、导出 Windows/Web，并发布带提交编号的可下载版本。构建过程见 [Actions](https://github.com/nOstalgia-April/FallBoard/actions)。

## 操作

| 操作 | 输入 |
|---|---|
| 选中己方棋子 | 左键点击 A / B |
| 移动 / 攻击 | 点击相邻空格 / 敌人；或使用方向键 |
| 查看攻击结果 | 选中己方棋子后，将鼠标移到相邻敌人 |
| 结束回合 | 点击按钮或按 E |
| 重开当前关卡 | 点击按钮或按 R |
| 切换关卡 | 左侧关卡按钮或数字键 1 / 2 / 3 |
| 取消选择 / 关闭说明 | Esc |

绿色圆点表示可移动格，珊瑚色边框表示可攻击敌人。预览会高亮双方接触面的数字，并显示比较式、击退箭头、推落 / 阻挡 / 失败结果。

## 规则与关卡

- 每方每回合共享 **2 AP**，同一棋子可行动两次。移动、成功攻击、失败攻击、被阻挡的攻击均消耗 1 AP；非法点击不消耗 AP。
- 四向数值始终为 **上、右、下、左**，不会因移动或攻击变化。
- 只有 **攻击值 > 对侧防御值** 才能推动目标一格。被另一枚棋子挡住时，不发生位移，也没有连锁击退。
- 被推出任一边缘立即死亡。敌方全灭则胜利，我方全灭则失败。
- **第 20 轮敌方行动结束**后仍未分胜负才判僵局；最后一行动造成全灭时，先判胜负。
- AI 优先推落，其次有效击退，否则移动到距存活玩家最近的空格。距离为曼哈顿距离；同分按关卡数据中的棋子顺序，再按上、右、下、左决定。无有效攻击且无空格可移动时结束回合。

| 关卡 | 体验目标 |
|---|---|
| 01 临界一推 | 两次攻击推落两个边缘敌人，学习接触面比较 |
| 02 一步之遥 | 开局不能直接击杀，先移动，再利用敌人的站位 |
| 03 让出一条路 | 队友挡住击退路线；A 负责向右，B 负责向上，双方都必须参与击杀 |

所有关卡都通过自动求解，解法使用与游戏相同的规则和确定性 AI。第三关并不要求唯一解；其初始最短解先让 B 移动，再让 A 击退。

## 改数值与继续开发

| 文件 | 用途 |
|---|---|
| `data/levels.json` | 三关的初始位置、数值、提示；坐标从 0 开始 |
| `scripts/battle.gd` | 独立规则、回合、胜负与 AI；无画面依赖 |
| `scripts/board_view.gd` | 棋盘、交互高亮与位移动画 |
| `scripts/piece_view.gd` | 棋子及四方向数字绘制 |
| `scripts/main.gd` | 中文界面、鼠标键盘输入、异步 AI 与重开取消 |
| `scenes/main.tscn` | 项目入口场景 |
| `export_presets.cfg` | Windows 与单线程 Web 的导出设置 |

每枚棋子的 `values` 数组按 **[上, 右, 下, 左]** 填写；`position` 为 **[列, 行]**，左上角是 `[0,0]`。不需要修改程序即可调整关卡。

为减小 Web 体积，中文字体只包含当前界面与关卡用到的字。增加文案后运行 `python tools/update_font.py`（先 `python -m pip install fonttools`），或将 `assets/fonts/FallBoardSans.ttf` 替换成完整的 Noto Sans SC 字体。

## 验证与导出

将 Godot 可执行文件加入 PATH 后运行：

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/ui_tests.gd
```

规则测试覆盖四方向比较、等值失败、阻挡、固定数值、AP、回合、20 轮边界、AI 优先级及三关可解性。界面流程测试覆盖选择、预览、三关完整通关、结果弹层，以及敌方行动 / 动画中重开。

当前自动断言为 **135 项规则检查 + 36 项界面流程检查**。CI 还会用实际图形渲染生成普通尺寸 / 小窗口截图，并在 Chromium 中加载导出的 Web 包、执行真实鼠标操作、保存第一关通关画面。截图随每个 Release 一起发布，便于核对构建结果。

在 Godot 编辑器中选择「项目 → 导出」，安装 **4.5.1 对应导出模板**后导出。命令行方式：

```sh
mkdir -p builds/windows builds/web
godot --headless --path . --export-release "Windows Desktop" builds/windows/FallBoard.exe
godot --headless --path . --export-release "Web" builds/web/index.html
python tools/package_builds.py
```

如需 GitHub Pages 在线试玩：在仓库 Settings → Pages 将 Source 设为 **GitHub Actions**；在 Settings → Secrets and variables → Actions → Variables 新增 `ENABLE_PAGES=true`；重新运行构建工作流。此开关只控制网页部署，Windows 下载始终独立生成。

## 验收边界

- 完整实现 PRD 的 v0.1 功能范围，未加入成长、商店、技能、连锁击退等排除项。
- 自动测试能验证规则、可解性和界面流程，不能证明玩法有趣。真人测试表见 [docs/playtest.md](docs/playtest.md)。
- Windows 导出未签名；实际 Windows 系统上的启动、显示与输入仍需要实机验收。
- 原 PRD 的第 8.2 节末尾截断。试玩表按「至少三名未参与设计的玩家，每人体验三关」这一明确要求编制，补充问题作为建议而非既定验收阈值。
- 第三方许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
