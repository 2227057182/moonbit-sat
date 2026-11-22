# 变更记录

版本号遵循 `moon.mod` 中的 `version` 字段。

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
