## 0.7.15 — 上一版里两处自指不一致

2026-11-24. 纯文档重发，代码与 0.7.14 逐位相同。0.7.14 发布后自查发现两处是自己造成的矛盾：

- `docs/november.md` 写「逐篇对照源码修正 8 处」，而本文件 0.7.14 段写 14 处——同一批改动的两种
  口径。统一为 14 处，并指向这里的明细，不再各自计数。
- `docs/usage.md` 的 FAQ 以「三种情况最常见」开头，随后列了三种；`docs/proof.md` 明确列四种。
  改成「常见的有三种」，避免读成「一共只有三种」。

## 0.7.14 — 逐篇遍历：修掉 14 处文档与事实不符

2026-11-24. 纯文档重发，代码与 0.7.13 逐位相同。把仓库每一篇文档对着源码与实测重读了一遍，
改的是「文档说的」与「仓库做的」不一致的地方：

- `examples/README.md` 开篇仍写「命令行不接受文件 IO（MoonBit core 没有文件系统模块）」，这是
  0.7.5 及以前的状态；改为 0.7.6 起的 `@路径` 用法，并附一条可直接跑的命令。
- `docs/proof.md`「判失败的三种情况」下面实际列了四条；RAT 一行写「不支持」，但
  `verify-rat` 有完整 RAT，只有默认的严格模式拒收；「已知缺口」里「没有一条命令能同时接收
  外部 `o`/`v` + 外部证明」在 0.7.7 就被 `maxsat-verify-external` 推翻了，整条删掉。
- `docs/usage.md` 给 `solve` 的输出多写了 `-1 0`：UNSAT 时它只打 `s UNSATISFIABLE`，
  `-1 0` 是 `proof` 的证明首行；命令列表缺 `maxsat-proof`；`maxsat-verify` 失败时的输出没写。
- `docs/api.md` 命令行块写 `maxsat "<WCNF 文本>" <weight_cap>`，但 CLI 没有第二个参数，
  上限固定 512；同时补齐 `verify-rat`、`core`、`grid-wcnf`、`bench`、`bench-verify`。
- `docs/benchmarks.md` 正文说「六个实例的返回值都与已知最优一致」，表里只有五行，缺 20×20
  那一行（`o 200`、32 s）；两处 `##` 标题前缺空行。
- `docs/roadmap.md` 的发布清单停在 0.6.3；「计划中」一节全是已完成项，改名并注明口径；
  三条未完成项分别写清为什么排在终审之后。
- `docs/november.md` 标题与发布统计停在 0.7.9，`docs/` 篇数写 11（实为 13），表格缺
  0.7.10–0.7.13 的成果——补「结论层对拍」「审计页与缺陷清单」「加权最优值外部裁判」
  「文档口径自查第二轮」四行。
- `CONTRIBUTING.md` 还要求把缺陷说明写进 `design.md`；`docs/fixes.md` 建立后应写进那里。
- README 两份（`README.md` / `README.mbt.md`）说「几千行的证明不可能作为命令行参数内联」——
  3942 行的 k=8 证明约 30 KB，内联得下，只有 24 MB 的 k=10 不行；索引里的版本范围同步到 0.7.14。
- `docs/reproduce.md` 正文里混进了三个控制字符（`ESC`、两个 `VT`），把一对反引号吃掉了，
  渲染出来是乱码，已还原；同时补上 PowerShell 等价写法（`$M = ...`、`(Get-Content f -Raw)`）。

`moon check --deny-warn` 零告警，`moon test` 95/95；本题只改文字，不动任何默认路径行为。

## 0.7.13 — 仓库内申报书副本跟上版本

2026-11-24. 纯文档重发，代码与 0.7.12 逐位相同。

- `docs/申报书.md` 仍写着「当前版本 v0.7.9」，与同一包里 README 的 0.7.12 冲突；
  这正是 0.7.11 那页 `docs/fixes.md` 第 8 条记录的口径矛盾类型。副本已同步到 0.7.13；
  此后版本号以 `moon.mod` 为准。

## 0.7.12 — 对拍收口：证明全验、最优值对暴力枚举

2026-11-24. 代码零改动，只补两处外部裁判，并把两处「抽样」边界去掉。

- `tools/difftest.sh` 默认改成全验 664 个 UNSAT 证明（此前每档抽 10 个、共 100 个）。
  重跑结果：1400/1400 结论一致、736 个模型全部满足、664 份证明全部 `s VERIFIED`，
  0 分歧 0 超时。开销可忽略——664 份 `drat-trim` 约 50 秒，单份耗时由进程启动主导。
  `PROOF_SAMPLE=N` 仍可退回抽样。
- 新增 `tools/maxsat_bruteforce.py`：随机 WCNF（8–16 变量、软权重 1–5）跑 `maxsat`，
  再把 2^n 个赋值全枚举取最小软代价，比「报的 `o` 是不是真最小值」。
  400/400 一致、0 不等、0 求解失败，整轮 9.4 秒。
  这是此前唯一缺外部裁判的环节：结论对拍只比 SAT/UNSAT，`maxsat-verify` 验的是自家
  上下界彼此一致，两者一起错时都看不出来。
- `docs/crosscheck.md` 补「加权最优值」一节与全验数据；README 两份同步；审计页加上这两条命令。

# 变更记录

版本号遵循 `moon.mod` 中的 `version` 字段。

## 0.7.11

### 新增两页审计文档（不改代码）

- `docs/audit.md`「十分钟审计」：把六条验收条目变成六组可执行命令，每条给出命令、预期输出，以及输出不符时意味着什么。写这一页时当场抓到自己一处错误——`grep -rn 'extern "'` 会把 `.mooncakes/` 依赖缓存与 `_build/` 生成物算进去（166 行），排除这两个目录后仓库自身源码为 0；页面里已改成带 `--exclude-dir` 的命令并写明原因。
- `docs/fixes.md`「修掉的缺陷」：9 条真实错误逐条记症状、怎么发现的、修法、防复发，末尾归纳四条正在起作用的机制（测试必须双向、外部对拍、量出来再改、文档审计）。
- README 索引与设计说明的交叉引用同步；求解器、检查器与库接口零改动，`moon check --deny-warn` 零告警、`moon test` 95/95。
## 0.7.10

### 外部结论对拍（新增工具，求解器零改动）

- 新增 `tools/difftest.sh`：以 CaDiCaL 3.1.0 为独立结论源，在 10 档随机 3-SAT（20–100 变量、共 1400 个实例，比例 4.26 与 5.00）上比对 SAT/UNSAT 结论，并核对见证。SAT 的 `v` 行交 `tools/check_model.py` 逐子句验证；UNSAT 的 DRAT 每档抽前 10 个交 `drat-trim`（664 个 UNSAT 共抽 100 个）。
- 结果：1400/1400 结论一致，736 个 SAT 模型全部满足公式，100 份 UNSAT 证明全部 `s VERIFIED`，0 分歧、0 超时、0 坏见证（单实例 20 s 上限，超时单独计数且不算通过）。
- 新增 `tools/gen3sat.py`（固定种子的随机 3-SAT 生成器）与 `tools/check_model.py`（纯 DIMACS 解析的模型校验，不依赖本项目任何代码）。
- 边界写在 `docs/crosscheck.md`：只覆盖随机 3-SAT，证明只抽样，CaDiCaL 用默认参数。
- 求解器、检查器与库接口零改动；`moon check --deny-warn` 零告警，`moon test` 95/95。

## 0.7.9

### 只重发文档（代码与包内容不变）

- 0.7.8 的包内文档停在修正前的口径：README 首页写「82 个测试、14 类硬证据」，同一页的命令块却是 `95 passed`；`CONTRIBUTING.md` 说「检查器不接受 RAT」，而 `verify-rat` 分支早已存在；申报书把 k=8 端到端写成 `0.7s`，仓库内三处口径都是 `0.14s`。这些已由仓库提交 `7223ab0` 修正，但 Mooncakes 展示的是发布时的旧副本。
- 本版不新增能力、不改代码：`moon.mod` 只改 `version`；文档除把「至 0.7.8」的版本表述改成「至 0.7.9」之外，与 `7223ab0` 一致。求解器行为、默认路径输出、证明与统计与 0.7.8 逐位相同。
- `moon check --deny-warn` 零告警；`moon test` 在 native / js / wasm / wasm-gc 四个后端各 95/95。

## 文档口径复核（2026-11-24，无代码改动）

- 四后端 `moon test` 实测：native / js / wasm / wasm-gc 各 95/95；`moon check --deny-warn` 零告警；四后端 `moon build --release` 均通过。0.7.8 发布时只复核了 native / js / wasm-gc，wasm 与 wasm-gc 的测试在本次补跑。
- 数字与口径对齐：README 证据数 82→95、证据类 14→17（追加 3 条）；`docs/reproduce.md` 90→95；申报书 90/82→95、k=8 端到端 0.7s→0.14s、预处理一句补成「轻量预处理」；`docs/november.md` 的 0.7.7 计时 3ms/66ms→5–10ms/62ms、子命令列表补 `maxsat-verify-external`、「至二十三日」→「至二十四日」；`docs/usage.md` 输出表补回 `maxsat-proof` 行；`docs/api.md` 补 `verify_maxsat_external` 签名行；`CONTRIBUTING.md` 修「校验器不接受 RAT」「总软权重一律受限」两处与实现不符的旧口径，并给 CLI 示例补上 `core` / `grid-wcnf` / `bench` / `bench-verify`。
- 代码、默认路径输出、证明与统计逐位不变。

## 0.7.8

### 求解器（只改内存，不改结果）

- 学习子句归约删掉的子句，以前只标 `dead`，文字数组仍被引用，随冲突数线性累积。现在标记的同时清空并释放文字数组（`lits.clear()` + `shrink_to_fit()`）。死子句不会再被读：传播碰 `lits` 前先查 `dead`，冲突分析只沿 `reasons` 与监听走到存活子句，`d ...` 删除行在标记之前已经写进证明。
- php-10（10 鸽 9 洞、182055 次冲突）实测：归约后死子句 113290 条，占 182469 条子句的 62%，死子句里 3155787 个文字比存活的 68764 条子句里的还多；峰值 RSS 112.4 MB → 92.3 MB（-18%）。
- 结果逐位不变：同一实例的 `decisions=216143 propagations=2298877 conflicts=182055 restarts=507 learnts=68764 minimised=976397` 与改动前完全一致，证明行数相同。时间没有可归因的变化（重复测量的壁钟在 210–248 s 之间摆动，CPU 时间 227.8 s → 239.4 s，属于同一测量区间），这项改动只去内存，不承诺提速。
- 随机 3-SAT（200 变量、阈值附近）三个种子：峰值 RSS 12160/7040/6640 KB → 10996/6524/6144 KB（-7% 到 -10%），CPU 时间摆动在 ±3% 内。
- 新增 2 个测试（`clause_pool_wbtest.mbt`）：归约后每条死子句的文字数组长度为 0 且 `learnts` 恰好剩一半；8 鸽 7 洞（会触发归约）在空壳子句组成的库上仍判 UNSAT。测试 93 → 95。
- 两处只改注释、不改逻辑：`sort_by_activity` 实际按活跃度降序排、归约删的是更活跃的一半（与旧注释「升序、删尾部」相反，但每个已发布版本都是这个行为）；插入排序在候选数上平方，实测不到端到端 1%，因此 0.7.8 试过的归并排序替代（逐位复现同样顺序）没有进主线，负结果记在 `docs/benchmarks.md`。

`moon check --deny-warn` 零告警，`moon test` 与 `moon test --target js` 均 95/95，native / wasm-gc / js 三个后端构建通过。（0.7.8 发布时只复核了这三个后端；wasm 与 wasm-gc 的 `moon test` 在 11-24 文档复核时补跑，四个后端均 95/95、`moon build --release` 均通过。）

## 0.7.7

### 命令行与库（新增能力，不改默认行为）

- 新增 `maxsat-verify-external <wcnf> <opt> <lits> <drat>` 与库函数 `verify_maxsat_external`：最优性两端都可以来自外部——赋值按 WCNF 原文重算代价，`opt-1` 的 DRAT 在重建出来的编码上重放，两条输入都不采信。此前 `maxsat-verify` 只能验自己算出的那一对，第三方想复核最优性没有入口。
- 新增 3 个测试（`maxsat_external_wbtest.mbt`）：两端皆真时通过、翻转赋值只坏上界、删掉空子句只坏下界。测试 90 → 93。
- 实测（CaDiCaL 3.1.0 在 native 上解 `maxsat-cnf` 导出的编码）：Petersen `opt=6` 的 k=5 证明 263 字节 14 行，两端复算 5–10 ms，与自家 `maxsat-verify` 的 5 ms 同量级；10×10 网格（100 顶点、5150 变量编码）证明 2835 行 22331 字节，复算 62 ms，而自家 `maxsat-verify` 从头算约 345 ms。两份外部证明交给 `drat-trim` 同为 `s VERIFIED`、0 RAT 引理。

`moon check --deny-warn` 零告警，`moon test` 与 `moon test --target js` 均 93/93，native / wasm-gc / js 三个后端构建通过。

## 0.7.6

### 命令行（会改变调用方式）

- 参数支持 `@path`：以 `@` 开头的参数按文件路径读取，用读到的文本替换原参数，公式与证明两侧都适用。以前只能内联，24 MB 的鸽巢 k=10 证明受单个参数 128 KB（Linux `MAX_ARG_STRLEN`）上限根本传不进来；现在 `verify @php-10.cnf @php-10.drat` 在 native 上整条命令 89 s 输出 `s VERIFIED`（含读盘与解析）。
- 读盘用官方 `moonbitlang/x/fs`（0.5.6）。这是第一个外部依赖，只在可执行包 `cmd/main` 里；库包仍只依赖 `moonbitlang/core`，`moon.mod` 的 `deps` 保持为空。native / wasm-gc / js 三个后端的命令行都能构建。
- 读不到文件时打印 `c error: cannot read file <path>` 并以 0 退出，不再把路径里的数字当成公式内容。
- 不以 `@` 开头的路径参数照旧挡下，提示从「用 `"$(cat file)"`」改为「用 `@path` 或 `"$(cat file)"`」。内联调用与默认行为完全不变。

### 检查器（会改变行为）

- 证明里出现公式未声明的变量（例如只有 2 个变量的公式配上 `999 0`）以前索引越界 abort（native 下 exit 134、SIGABRT），现在由 `steps_in_range` 判为无效证明，输出 `s PROOF-REJECTED`。DRAT 的变量范围由公式头决定，超出即是错误证明。
- 代价是 24 MB 证明多一遍变量范围扫描：native 实测 89.1 s → 89.6 s（+0.6%）。
- 新增 3 个测试（`checker_guard_wbtest.mbt`）：越界证明被拒、范围内证明仍 `VERIFIED`、越界行出现在空子句之前也不会被判成功。测试 87 → 90。

`moon check --deny-warn`（默认与 native 目标）零告警，`moon test` 与 `moon test --target js` 均 90/90，native / js / wasm-gc 三个后端的 `moon build --release` 全过。

## 0.7.5

### 文档

- `docs/proof.md` 新增「裁剪式复算：实测 87% 是核心」：给检查器的传播加临时 `reason` 记账（探针不进仓库），从空子句沿依赖反推。k=8 核心 1023/2945（35%）、k=9 25193/27102（93%）、k=10 158437/182055（87%）；带探针的端到端 k=10 是 346.7 s，比不带探针的 327.2 s 多 6%。
- `docs/roadmap.md`：裁剪式复算从待做改为「已评估，不做」，并说明 `drat-trim` 的 172527/295345 是证明行数口径，与添加子句口径不可比。

没有求解器、检查器、API 或 CLI 的行为变更，探针代码不在仓库里。
## 0.7.4

### 输入面（会改变行为）

- 负权重 WCNF 以前让 `maxsat` / `maxsat-oll` 直接 abort（exit 134，无输出）：负权重让总软权重变小，二分把负预算交给计数编码，最终在 `s_vars[0][0]` 越界。现在解析后由新的 `wcnf_error` 报出 `WCNF soft weight -5 is negative`；`maxsat_solve` 对负权重 `raise`，`maxsat_encoding` 对 `k < 0` 直接返回空子句。
- 缺少 `p wcnf <vars> <clauses> <top>`、或 header 缺 TOP 的实例，以前 `top` 回落成 0 或子句数，所有软子句被当硬子句、结论被静默改判。现在同样在解析后拒绝。
- 命令行整数参数（`maxsat-cnf` / `maxsat-proof` / `verify-maxsat` 的 k、`maxsat-oll-budget` 的轮数、`verify-solution` 的代价）遇到非数字以前读成 0（`rounds=0` 就是「不限轮」），现在报错。`bench-verify` 的 k 超出 6..10 以前静默回落到 8，现在报错。
- 新增 5 个测试（`wcnf_guard_wbtest.mbt`）：合法实例无错、无 header、缺 TOP、负权重（含库层面抛错）、负 k 不可满足。测试 82 → 87。

求解器与检查器本身的行为没有改变（同一公式、同一证明结论相同），变的是输入面的拒绝方式。共 9 处 WCNF 检查与 5 处整数参数检查，`moon check --deny-warn` 零告警、87 个测试全过。

## 0.7.3

### 接口文件

- `pkg.generated.mbti` 重新生成。0.7.0 就公开了的 `maxsat_oll`、`maxsat_oll_result`、`maxsat_oll_solution` 和 `OllOutcome` 一直没写进这份生成文件，外部按它看会漏掉三个函数与一个枚举。

### 文档

- `docs/proof.md` 新增「RUP 复算为什么改不动数字」：k=9 证明的逐次计数（27102 次检查、9881 万次监听访问、4335 万次监听搬家）、四种监听表存法的同机对照、以及为什么真正的方向是裁剪式复算。
- `docs/roadmap.md`：校验器提速从待做改为「已评估，结构改动不动数字」，新增「裁剪式复算」条目。

没有求解器、检查器、API 或 CLI 的行为变更。

## 0.7.2

### 文档

- `docs/proof.md` 新增「为什么没有 at-least 基数网络」：三组实测（Petersen 每条 100、20×20 每条 100、20×20 半 100 半 200）显示下界每轮只涨 `wmin`；at-least-k 的 k 上界是 `min_i(w_i)/wmin`，而 `wmin` 就是组内最小值，商恒为 1，每轮都会退化成一条 at-least-1 子句。
- `docs/roadmap.md` 对应条目从待做改为「已评估，不实现」，并在「不做」里写明不为了完整性写一个走不到的分支；真正能减少轮数的方向（不相交多核提取、totalizer 分层计费）单独记下。

没有代码、API 或 CLI 行为变更。
## 0.7.1

### 测试

- 新增 `external_proof_wbtest.mbt`：把 CaDiCaL 3.1.0 对鸽巢 6 鸽 5 洞写出的 235 行 DRAT（156 条添加、79 条删除）与对应公式（82 行）原样内联，`verify_proof` 与 `verify_proof_rat` 都通过；另一个测试删掉末尾空子句，确认同一份证明被拒绝。
- `drat-trim` 对同一份证明也是 `s VERIFIED`（0 RAT 引理），三家结论一致；鸽巢 7 鸽 6 洞（1846 行 / 37 KB）同样通过。

### 文档

- `docs/crosscheck.md` 新增「反方向：别人产的证明，我们验」，记录 CaDiCaL 3.1.0 的编译方式与命令、三家检查结果、拒绝路径，以及 RAT 分支仍无真实外部样本的边界。
- README 与 `docs/crosscheck.md` 的硬证据从 13 类升到 14 类，测试数 80 → 82。

没有代码、API 或 CLI 行为变更。
## 0.7.0

### 新增

- `maxsat_oll_result(w, max_rounds) -> OllOutcome`：给核心引导一个轮预算。`Solved(赋值, 代价)` 表示收敛；`Infeasible` 表示硬子句本身不可满足；`Budgeted(下界, 上界)` 表示预算用尽——下界只由 core 推进，上界从总软权重起步、每找到一个模型就下降，两者之差就是剩余缺口。`max_rounds <= 0` 表示不限。一轮是一次核心查询加记账，对同一输入是确定的，不是墙钟时限。
- CLI 新增 `maxsat-oll-budget <wcnf> <rounds>`：收敛时输出 `o` / `v` / `s SOLUTION-VERIFIED`，预算用尽时输出 `c rounds= … lower= … upper= …` 与 `s UNKNOWN (round budget exhausted)`。
- 总软权重 40000 的 20×20 加权网格给 20 轮，不到 10 ms 就返回 `lower= 2000 upper= 40000`；同一实例不设预算会一直跑下去。

### 测试

- 新增三条：预算用尽返回 `Budgeted` 且上下界不闭合、预算超过自然轮数时与无预算结果一致、`rounds <= 0` 视为不限。
- 新增一个三条三元超边的加权超图实例（硬子句长度 3、软子句为单元），与编码路径等比缩放对拍得 `o 200`，模型成本按 WCNF 复算一致——此前核心引导的用例全是图上的二元边，这是第一个非该形态的实例。

测试 77 → 80，`moon check --deny-warn` 零告警，12 个外部案例的结论不变。

## 0.6.9

### 文档

- 包内 README 与 `docs/` 对齐 0.6.8 的实际内容：测试数 68 → 77（硬证据 11 → 12 类，新增核心引导一条）、子命令 15 → 16（补 `maxsat-oll`）、「范围边界」里的 MaxSAT 上限改成「`maxsat_solve` 有上限、`maxsat_oll` 无上限，≤512 自动走编码」。
- `docs/november.md` 的发布行与提交数、`docs/reproduce.md` 与 `docs/crosscheck.md` 的案例数（10 → 12）同步；`docs/crosscheck.md` 里 k=10 的检查器耗时补上 0.6.7 之后的 127 秒。

没有代码、API 或 CLI 行为变更，0.6.8 的能力与边界一字未改。

## 0.6.8

### 新增

- `maxsat_oll` / `maxsat_oll_solution`：核心引导的加权 MaxSAT。每条软子句带自己的松弛文字；命中 core 后按 `wmin` 记账、饱和这一层，剩余权重交给新的松弛文字，所以同一条子句被多个 core 命中也不会重复收费。下界只增不减，同时把「模型违反的软子句」写成阻塞子句收紧上界，两界相接、或阻塞之后再没有更便宜的解时收尾。
- 这条路径不建基数编码，因此没有 `maxsat_solve` 的 `weight_cap`。软权重 100 的 Petersen（总权重 1000）交给 `maxsat` 会直接抛上限错误，`maxsat-oll` 7 ms 给出 `o 600`。
- 总软权重 ≤ 512 时自动改走编码路径：均匀小权重的大图上核心引导每轮只推进一层，编码快得多（8×8 网格 45 ms，同一实例核心引导 200 s 未收敛）。
- CLI 增加 `maxsat-oll <wcnf>`：打印 `o`、`v` 与 `s SOLUTION-VERIFIED`。

### 边界

- 均匀权重的大图不适合核心引导，轮数与最优值同量级；20×20 加权网格没有跑完。这条路径针对的是「权重远大于编码上限」的实例。
- 核心引导不导出下界证明：每轮 core 依赖求解器的假设接口，没有可移植的证明文本。外部复核最优性仍走 `maxsat-cnf` / `maxsat-proof` 的编码路径。

测试 68 → 77，`moon check --deny-warn` 零告警，12 个外部案例的结论不变。

## 0.6.7

### 改动

- 检查器的子句池从一堆独立小数组摊平成一维 `Array[Lit]`：`begin`/`len` 划界，`len == 0` 表示删除，省掉 `alive` 数组和每次监听命中里的两层指针跳转。
- 端到端（构造、求解、取证明、校验）：k=9 6.00s → 5.30s，k=10 435s → 366s；单独计时后纯校验部分是 k=9 约 2.5s → 1.9s、k=10 约 196s → 127s。
- 与 `drat-trim` 的差距从约 11 倍缩到约 7 倍。剩下的差距在传播调度，不在监听结构。

### 试过但回退

- 每 5000 步重建监听表、一次性摘掉死子句：实测无收益，已回退。
- 把两个监视文字与长度复制成三整数一组的元数据数组：实测同样无收益，已回退。

测试仍是 68，`moon check --deny-warn` 零告警，12 个外部案例的结论未变。## 0.6.6

### 新增

- `docs/benchmarks.md` 增加「规模上限：鸽巢 k=10」：90 变量、295345 行证明、求解 223 s；同一条证明本项目检查器约 350 s，`drat-trim` 约 17 s，`lrat-check` 约 0.7 s。
- 20×20 网格最小点覆盖（400 变量、1200 子句）：`maxsat` 32.3 s 给出 `o 200`（König 定理独立佐证），`maxsat-verify` 81 s 得到 `c upper= true lower= true`。`opt-1` 的 Sinz 编码膨胀到 80201 变量、159964 子句。
- `tools/crosscheck.sh` 增加 `BIG=1` 分支，把鸽巢 10/9 与 20×20 下界证明一起交给 `drat-trim` 与 `lrat-check`；默认运行不受影响。

### 边界

- 鸽巢 k=11（110 变量、561 子句）没有跑：从 k=9 到 k=10 求解耗时放大约 59 倍，按同一斜率推算 k=11 需要数小时，90 秒试探未完成。这是估算，不写成已完成的能力。
## 0.6.5

### 新增

- `maxsat-cnf <wcnf> <k>`：打印 `maxsat_encoding(w, k)` 的 DIMACS 文本。这条命令是给外部检查器用的——在这之前，最优性下界证明只能用自己的检查器复验，因为外人拿不到「公式」。
- `tools/crosscheck.sh`：自动下载并编译 `drat-trim` 与 `lrat-check`，对鸽巢 3–9 洞、以及三个加权实例的 `opt-1` 不可达证明共 10 个案例做交叉验证。任一案例失败则退出码非 0。
- `docs/crosscheck.md`：方法、10 个案例的结果表、`drat-trim` 的 RAT 分项统计，以及没做到的部分。

### 修复

- 命令行把文件路径当公式文本解析：`proof examples/pigeonhole-3-2.cnf` 会从文件名里抠出数字，凑出一个小公式并打印 `s SATISFIABLE`。对求解器来说这是最坏的失败模式——不是报错，是给出一个自信的错误答案。现在参数里没有 `p cnf` / `p wcnf` 头、同时含 `/`、`\`、`.cnf`、`.wcnf` 时直接给出错误提示与正确写法（`"$(cat file)"`），`solve` / `proof` / `verify` / `maxsat` / `maxsat-cnf` 都覆盖。

### 验证

- 68 个测试通过（新增 1 个：编码经 DIMACS 往返后 `num_vars` 与子句数不变，且「代价 0 不可满足 / 代价 1 可满足」与内部编码一致）。
- 外部交叉验证 10 个案例全绿：`drat-trim` 的 `s VERIFIED` 与 `lrat-check` 的 `c VERIFIED` 同时成立。`drat-trim` 的 `-f` forward 模式对鸽巢 3/7/9 各跑一遍，结论相同。
- `drat-trim` 统计显示全部案例 **0 RAT 引理**，即输出证明是纯 DRUP，只需 RUP 就能验，对检查器的要求降到最低。
## 0.6.4

### 新增

- `maxsat_model(w, weight_cap) -> (Array[Bool], Int)?`：与 `maxsat_solution` 相同的返回值，但**不抛异常**。超权重上限时返回 `None` 而不是 raise，因此普通 `fn main` 里可以直接调用，首次接入不必写 `try` 或 `fn main raise`。
- `docs/reproduce.md`：从 clone 到六条证据的复现步骤，每条给出预期输出。
- `docs/november.md`：本期实质新增的清单，按能力排列并标出可核对位置。
- `README` 增加「最小可运行工程」：`moon add` 之后可直接粘贴的 `moon.pkg` 与 `main.mbt`，并给出 `moon run .` 的预期输出。

### 修复

- `verify` / `verify-rat` 在证明文本包含 `c` 注释行时直接 abort（进程崩溃，不是返回拒绝）。根因在 `parse_drat`：只跳过空行，其余行一律当「添加子句」处理，于是 `c decisions=1 propagations=9 …` 里的数字被当成了字面，检查器数组越界。现在只接受以数字、`-`、`d` 开头的行，`c` / `s` / `o` 等一律跳过。这个缺陷自 0.5.0 就存在，影响所有「把命令行打印的 `s` 与 `c …` 统计原样回喂给 `verify`」的用法，也让外部 DRAT 文件里的注释行无法使用。

### 验证

- 67 个测试在 wasm 与 js 后端通过；新增 2 个覆盖 `maxsat_model`（正常实例返回值与 `maxsat_solution` 一致、超上限返回 `None` 而同实例的 `maxsat_solution` 确实抛出），3 个覆盖注释行（带 `s` 与 `c …` 的合法证明仍 VERIFIED、只含注释的文本得到 PROOF-REJECTED 而非崩溃、空子句后跟注释仍 VERIFIED）。
- `verify` 复验：`pigeonhole-3-2` 的证明原样回喂（含 `c …` 统计行）→ `s VERIFIED`，退出码 0；0.6.4 之前同一命令 abort。
- 在干净的 Linux 工程里从 Mooncakes 安装 0.6.4，按 README 抄一遍代码即可 `moon run`，输出 `cost=1` 与 `verified=true`。

### 边界

- `maxsat_model` 把「超权重上限」与「硬子句不可满足」两种情况都折成 `None`，调用方无法区分原因。需要区分时用 `maxsat_solution` 的异常分支。
- `moon update` / `moon add` 依赖本机有 git 可用；缺 git 时索引无法更新，报 `program not found`，与模块本身无关。

## 0.6.3

### 新增

- `maxsat_solution(w, weight_cap) -> (Array[Bool], Int)?`：求最优值后在同一份编码上再解一次，把达到该值的完整赋值取回来。硬子句不可满足时返回 `None`。
- `maxsat_model_cost(w, model) -> Int`：独立复算一个赋值的代价——硬子句任一被破坏即返回 `-1`，否则累加被违反软子句的权重。它不信任任何先前的求解结果，只按 WCNF 原文重算。
- `verify_maxsat_solution(w, model, claimed_cost) -> Bool`：声称的代价与实际重算结果必须一致。
- 命令行 `maxsat-solution <wcnf>`：输出 `o <cost>`、`v <lits> 0` 与 `s SOLUTION-VERIFIED`，拿到的是可以直接抄进别的工具的值。
- 命令行 `verify-solution <wcnf> <cost> <lits>`：只吃外部给的代价与赋值，重新解析后复算，用于第三方复核或篡改实验。

### 变更

- `maxsat-verify <wcnf>` 从「只验下界」改为双端校验：先求最优 `opt`，再分别得到上界（存在代价恰为 `opt` 且经复算通过的赋值）与下界（`opt-1` 不可达的证明），输出 `c upper= <bool> lower= <bool>`，两端皆真才给 `s OPTIMALITY-VERIFIED`。
- **输出格式变化**：`opt=0` 的实例不再打印 `s OPTIMALITY-VERIFIED (no soft clause needs to fail)`，改为与其它实例一致的 `c upper= true lower= true` 加 `s OPTIMALITY-VERIFIED`。按旧字符串做匹配的脚本需要改。

### 验证

- 62 个测试在 wasm 与 js 后端通过；新增 6 个：最优赋值确实付出所声称的代价、声称代价偏大或偏小均被拒、破坏硬子句的赋值被拒、零代价实例仍给出可校验赋值、硬子句本身不可满足时返回 `None`、以及顶点覆盖实例上「上界 + 下界」合起来才判为最优。
- native 实测（Ubuntu 云主机）：`maxsat-verify` 在 Petersen、4×5 网格、scheduling 三个实例上均输出 `c upper= true lower= true`；10×10 网格的完整双端校验耗时 347ms。
- 篡改实验（Petersen，`o 6`）：原样回放 `s SOLUTION-VERIFIED`；把 `v` 行里的 `3` 翻成 `-3`、把声称代价改成 `5`、把全部变量置假，三种都得到 `s SOLUTION-REJECTED`。

### 边界

- 上界只证明「这个赋值达到 `opt`」，单独看它并不排除更低的代价；只有和 `opt-1` 不可达的证明放在一起才闭合最优性，这也是 `maxsat-verify` 现在两端都要过的原因。
- 复算用的是本库的 WCNF 语义（`top` 值、重复权重按原样累加），不覆盖其它 MaxSAT 格式的扩展约定。

## 0.6.2

### 新增

- `maxsat_encoding(w, k) -> Formula`：把「软子句代价 ≤ k 是否可行」显式构造成一个 CNF。硬子句原样保留，每条软子句加一个 select 变量并进入按权重重复的松弛数组，再用 Sinz 计数编码限制其和。构造是确定性的——同样的实例和 k 一定得到同样的公式，这是下界证明能被复算的前提。
- `maxsat_bound_proof(w, k) -> String?`：代价 `k` 不可达时返回一份 DRAT 证明，可达时返回 `None`。
- `verify_maxsat_bound(w, k, proof) -> Bool`：重建同一个编码后重放证明，判定它是否真的证明了 `k` 不可达。
- 命令行 `maxsat-proof <wcnf> <k>`、`verify-maxsat <wcnf> <k> <proof>` 与 `maxsat-verify <wcnf>`；后者一条命令完成「求最优 → 导出 `opt-1` 的下界证明 → 当场校验」。

### 验证

- 56 个测试在 wasm 与 js 后端通过；新增 6 个测试覆盖：不可达下界能出证且校验通过、可达下界不出证、删掉空子句后被拒、证明不能挪用到另一个 k、硬子句本身不可满足时下界证明仍可校验。
- native 实测（Ubuntu 云主机）：`maxsat-verify` 在 Petersen（`o 6`）、4×5 网格（`o 10`）、scheduling（`o 1`）、10×10 网格（`o 50`）四个实例上均输出 `s OPTIMALITY-VERIFIED`。
- 篡改实验：Petersen 的 `k=5` 证明共 14 行，去掉末尾空子句后由 `s VERIFIED` 变为 `s PROOF-REJECTED`。
- 重构后原 50 个测试未变，说明把编码从「在 Solver 上增量构造」改为「写进 Formula」没有改变语义。

### 边界

- 证明是对**扩展后 CNF**（含 select 变量与 Sinz 计数变量）给出的，校验方必须用本库的 `maxsat_encoding` 重建同一份公式。所以这是「可复算」而不是「不看编码也能独立验」——与 SAT 侧 `verify` 拿原始 CNF 直接重放的性质不同，这一点在 `docs/proof.md` 里写明。
- 最优性证明只覆盖「`k` 不可达」，不覆盖「`k` 可达」（后者是模型，本版本不导出）。
- `Formula::add` 不会自动扩大 `num_vars`，编码器必须自己维护变量编号；这一点已在注释与 CHANGELOG 中记下，避免后来者踩同一个坑。

## 0.6.1

### 新增

- `grid-wcnf <rows> <cols>` 子命令：把 n×m 网格的最小顶点覆盖 WCNF 实例打印到标准输出（每条边一条硬子句 `(u v)`，每个顶点一条权重 1 的软子句 `(-v)`），一条命令就能复现基准实例。
- `examples/petersen-mwvc.wcnf` 与 `examples/grid-mwvc.wcnf`：Petersen 图与 4×5 网格的最小顶点覆盖实例。
- `docs/benchmarks.md`：实例来源、已知最优的依据、native 实测耗时、复现命令与局限。
- 3 个测试锁定最优值：Petersen 图 = 6、4×5 网格 = 10，以及 core 下界不超过最优。

### 验证

- 50 个测试在 wasm 与 js 后端通过。
- native release 实测（Ubuntu 云主机，每个实例 5 次取最小值）：Petersen 1.1ms、4×5 1.7ms、6×6 10ms、10×10 160ms、scheduling 0.8ms；五个实例的返回值与已知最优全部一致。
- 已知最优有独立依据：Petersen 靠「5 顶点覆盖要求独立集、而独立数是 4」的下界论证，网格靠 König 定理（二分图最小顶点覆盖 = 最大匹配）。

### 说明

- 对比对象是经典图上理论已知的最优值，不是 MaxSAT Evaluation 的参赛求解器；没有在工业数据集上做过比较，这一点在 `docs/benchmarks.md` 的「局限」里写明。

## 0.6.0

### 新增

- `Solver::solve_core(assumptions) -> (Bool, Array[Lit])`：判定 UNSAT 时额外返回假设的一个子集，该子集**本身不可满足**。提取方式是沿最终冲突的 reason 图回溯（`analyze_final`），只收集为假设建立的决策层；不保证最小，但保证单独拿这个子集去求解仍然 UNSAT。硬子句本身不可满足时返回空 core。
- `maxsat_core_bound(w)`：用一个 unsat core 给出最优代价的下界——core 内的软子句不能同时成立，最便宜的那条必然被违反。硬子句不可满足返回 `-1`，软子句可全部满足返回 `0`。
- `maxsat_solve` 的二分区下端点改为从该下界起步，省掉一部分注定失败的判定。
- 命令行 `core <dimacs> <lits>`：打印给定假设的 unsat core；空 core 表示与假设无关、硬子句本身已不可满足。

### 验证

- `moon check --deny-warn` 无告警；47 个测试在 wasm 与 js 后端通过。
- core 合法性不是靠断言长度判断的：每个报告出来的 core 都被单独作为假设重新求解，必须仍然 UNSAT；另有测试确认无关假设不会混进 core。
- 下界与暴力枚举出的最优值对拍（含 `maxsat_solve` 的既有随机对拍），未出现下界高于最优的越界。

### 边界

- 这不是完整的 OLL/WPM1 core-guided 求解器。完整实现需要稳定的松弛变量体系与权重拆解（每轮把 core 的最小权重扣掉、并把 core 的析取作为新软子句回收），这些基础设施本版本没有建。当前只做了 core-guided 的最小可用部分：core 提取 + 下界收紧。

## 0.5.0

### 新增

- 命令行 `bench-verify <k>`：进程内构造 `k` 鸽 `k-1` 洞实例、求解、取证明文本、统计行数并校验。操作系统对单个命令行参数有上限（Linux 为 128KB），`k >= 8` 的证明根本传不进去，这个子命令绕开该限制，同时给出可复现的校验耗时基线。

### 变更

- 检查器由「每条 RUP 全量扫描子句池」改为两文字监听（watcher）增量传播：`CheckDb` 持有子句池、`alive` 标记、每个文字的监听列表、赋值数组与 trail；`propagate` 只处理被置假文字对应的监听列表，命中子句就地转移监听点或触发单位赋值。
- 单元子句构成 trail 的基座层，`reset` 只回滚假设层之上的赋值，单元事实不再每次重播。
- 删除步骤走开放式子句哈希（8192 桶）定位，不再线性扫描整个池。
- 传播时监听列表就地压缩，省掉每轮一次数组分配。
- 证明中出现超出 `num_vars` 的变量时自动扩容，不再按声明范围判定。

### 验证

- `moon check --deny-warn` 无告警；37 个测试在 wasm 与 js 后端通过。
- 同一批证明（行数逐字不变）在 native release 下重新计时：`k=7` 0.04s → 0.02s、`k=8` 0.66s → 0.16s、`k=9` 32.56s → 5.96s，k=9 提速 5.5 倍且仍判 `VERIFIED`。
- k=10（295345 行、90 变量）约 350s：鸽巢证明的子句数远多于变量数，平均每个文字挂着数千条监听，传播成本是结构性的，已记入 roadmap。

## 0.4.0

### 新增

- RAT 校验：`check_drat_rat` / `verify_proof_rat` 在 RUP 失败后按 pivot 求归结，归结式仍需为 RUP；池中没有含否定 pivot 的子句时直接成立，因此能接受引入新变量的定义步骤。`check_drat` / `verify_proof` 保持严格 RUP 语义不变。
- 命令行 `verify-rat` 子命令，走完整 RUP + RAT 规则；`verify` 仍是严格模式。

### 验证

- `moon check --deny-warn` 无告警；37 个测试通过（新增 4 个 RAT 测试，含「RUP 拒绝而 RAT 接受」与「两种模式都拒绝」两类）。
- 求解器自身产出的证明在 strict 与 full 两种模式下结论一致，确认 RAT 没有放松对自家证明的判定。

## 0.3.0

### 新增

- 递归学习子句最小化：断定为文字之外，reason 链完全被子句或 0 层覆盖的字面会被删除；`minimised` 统计累计删除量并出现在 `stats_string`。
- 命令行 `bench` 子命令：在固定的随机 3-SAT 阶梯上输出决策、传播、冲突与最小化删除量，实例由写死种子的线性同余发生器生成，可复现。

### 验证

- `moon check --deny-warn` 无告警；33 个测试通过（新增 3 个最小化测试）。
- 最小化后的证明在 5 鸽 4 洞实例上仍被独立检查器判定为 `VERIFIED`。

## 0.2.0

### 新增

- `Solver::solve_with_budget` 与 `SolveOutcome`（`Satisfiable` / `Unsatisfiable` / `Unknown`）：限制冲突数，超预算即回退到 0 层并保留学习子句，可继续求解。
- `docs/usage.md`：安装、库调用、命令行输出格式与常见问题。
- `docs/origin.md`：算法出处、依赖情况、许可证与证明校验独立性说明。

### 变更

- 重启策略由线性增长改为 Luby 序列，间隔为 `100 * luby(restarts)`。
- README 补充冲突预算说明与两份新文档的入口。

### 验证

- `moon check --deny-warn` 无告警；30 个测试在 wasm 与 js 后端通过。

## 0.1.1

### 新增

- `Formula::simplify`：子句内重复文字去重、重言子句（同时含 `l` 与 `¬l`）消除，返回删除条数。
- `Formula::num_tautologies`：只读统计重言子句数量，便于提示冗余输入。
- `edge_wbtest.mbt`：11 个边界测试，覆盖空公式、空子句、重复文字、重言子句、变量越界、证明删除行、连续假设调用、MaxSAT 硬冲突与无软子句实例。
- `docs/design.md`：算法与数据结构设计说明，含关键不变量与真实缺陷的修复记录。
- `docs/api.md`：公开接口逐项说明。
- `docs/roadmap.md`：已完成与计划项清单。
- `examples/`：DIMACS 与 WCNF 样例实例及运行说明。
- `.github/ISSUE_TEMPLATE/`：缺陷与需求模板。

### 修复

- `parse_dimacs` 忽略独占一行的 `0`，导致空子句被静默丢弃、本应 UNSAT 的输入被判为 SAT。现在 `0` 按 DIMACS 严格语义产生空子句。

### 验证

- `moon check --deny-warn` 无告警。
- 24 个测试在 wasm 与 js 后端全部通过。

## 0.1.0

首个可运行版本。

- CDCL 求解器：双监听传播、1-UIP 分析、VSIDS、相位保存、线性重启、LBD 归约。
- DRAT 风格证明记录与独立 RUP 校验器。
- WCNF 解析、Sinz 基数编码、二分最优化。
- 四后端构建（wasm / wasm-gc / js / native）。
- 命令行入口（solve / proof / verify / maxsat）。
