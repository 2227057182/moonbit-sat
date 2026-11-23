# API 参考

所有接口都在包 `2227057182/moonbit-sat` 的根中，不需要额外导入子包。

## 字面 `Lit`

`Lit` 是 `Int` 的别名，编码为 `2 * var + sign`，`var` 从 0 开始。

| 接口 | 签名 | 说明 |
| --- | --- | --- |
| `lit_new` | `(v : Int, neg : Bool) -> Lit` | 由变量下标与符号构造字面 |
| `lit_var` | `(l : Lit) -> Int` | 取出变量下标 |
| `lit_is_neg` | `(l : Lit) -> Bool` | 是否为负字面 |
| `lit_neg` | `(l : Lit) -> Lit` | 取补；对负数输入会 abort |

## 子句 `Clause`

求解器内部用的子句节点，包含两个字面监听位置。一般不需要手工构造。

| 接口 | 说明 |
| --- | --- |
| `Clause::new(lits, learnt)` | 构造子句，监听位置初始化为 0 与 1 |
| `Clause::size()` | 子句长度 |
| `Clause::watch_at(which)` | 读取第 `which`（0/1）个监听位置 |
| `Clause::move_watch(which, pos)` | 移动监听位置 |
| `Clause::mark_dead()` | 标记为已删除 |
| `Clause::set_learnt(v)` / `Clause::add_activity(v)` / `Clause::set_lbd(v)` | 元信息写入 |

## 公式 `Formula`

| 接口 | 签名 | 说明 |
| --- | --- | --- |
| `Formula::new` | `(num_vars : Int) -> Formula` | 建一个空公式，声明变量数 |
| `Formula::add` | `(lits : Array[Lit]) -> Bool` | 追加子句；空子句返回 `false`（公式立即 UNSAT） |
| `Formula::num_clauses` | `() -> Int` | 子句数（含空子句） |
| `Formula::num_tautologies` | `() -> Int` | 统计重言子句（同时含 `l` 与 `¬l`）数量，不修改公式 |
| `Formula::simplify` | `() -> Int` | 去重子句内重复文字、删除重言子句，返回删除条数。**必须在 `Solver::new` 之前调用** |
| `parse_dimacs` | `(text : String) -> Formula raise` | 解析 DIMACS CNF。变量声明与实际不符时自动扩大变量数 |
| `to_dimacs` | `(formula : Formula) -> String` | 输出 DIMACS 文本，变量按 1 基编号 |

`parse_dimacs` 的细节：

- `c` 开头为注释，`p` 开头为声明行，其余按整数扫描。
- 单独一行 `0` 表示**空子句**，公式因此 UNSAT。这是 DIMACS 的严格语义，旧版本会忽略它，属于已修复的缺陷。
- 声明 `p cnf 1 1` 但出现变量 3 时，实际变量数扩大到 3，不报错。

## 求解器 `Solver`

| 接口 | 签名 | 说明 |
| --- | --- | --- |
| `Solver::new` | `(formula : Formula) -> Solver` | 由公式构造，完成 0 层单位传播 |
| `Solver::new_var` | `() -> Int` | 分配新变量，返回其下标（供编码使用） |
| `Solver::enable_proof` | `() -> Proof` | 打开证明记录，返回可读取的 `Proof` |
| `Solver::solve` | `(assumptions : Array[Lit]) -> Bool` | 求解。返回 `true` 时可调用 `model()`；返回 `false` 表示当前假设下不可满足 |
| `Solver::solve_core` | `(assumptions : Array[Lit]) -> (Bool, Array[Lit])` | 同 `solve`，UNSAT 时额外返回假设的一个子集，该子集本身不可满足；空数组表示与假设无关、硬子句本身 UNSAT |
| `Solver::model` | `() -> Array[Bool]` | 每个变量的取值，未赋值变量按 `false` 处理 |
| `Solver::add_clause` | `(lits : Array[Lit]) -> Bool` | 增量追加约束（回退到 0 层，保留学习子句）；返回 `false` 表示公式已 UNSAT |
| `Solver::value_lit` | `(l : Lit) -> Int` | `1` 为真、`0` 为假、`-1` 为未赋值 |
| `Solver::decision_level` | `() -> Int` | 当前决策层 |
| `Solver::stats_string` | `() -> String` | 一行统计：决策数、传播数、冲突数、重启数、学习子句数、最小化删除的字面数 |

`assumptions` 的语义：按顺序在 0 层之上做临时决策。任一假设冲突时返回 `false`，但**不会**让求解器进入永久 UNSAT 状态，后续 `solve([])` 仍然有效。

`solve_core` 返回的 core 不保证最小：它来自最终冲突的 reason 图回溯（`analyze_final`），只收集为假设建立的决策层，因此可能比最小 core 大。它的用途是「解释为什么这组假设不成立」以及给 MaxSAT 提供下界，不是做最小化。任何时候都成立的性质只有两条：core ⊆ assumptions，且 core 单独作为假设求解仍是 UNSAT。

## 证明 `Proof`

| 接口 | 说明 |
| --- | --- |
| `Proof::new()` | 空证明 |
| `Proof::add(lits)` | 追加一条学习子句 |
| `Proof::delete(lits)` | 追加一条删除行（`d ...`） |
| `Proof::empty()` | 追加终结空子句 |
| `Proof::text()` | 输出完整 DRAT 文本 |

`Proof` 由 `enable_proof` 创建，求解器内部会持续写入。不要在求解中途调用 `text()` 并期望得到完整证明。

## 校验器

| 接口 | 签名 | 说明 |
| --- | --- | --- |
| `parse_drat` | `(text : String) -> Array[DratStep]` | 把 DRAT 文本解析为步骤列表 |
| `check_drat` | `(formula : Formula, steps : Array[DratStep]) -> Bool` | 逐条 RUP 校验，并要求以空子句结束 |
| `check_drat_rat` | `(formula : Formula, steps : Array[DratStep]) -> Bool` | RUP 失败后追加 RAT 判定，同样要求空子句 |
| `verify_proof` | `(formula : Formula, proof_text : String) -> Bool` | `parse_drat` + `check_drat` 的组合 |
| `verify_proof_rat` | `(formula : Formula, proof_text : String) -> Bool` | `parse_drat` + `check_drat_rat` 的组合 |

`check_drat` 独立于求解器：它自己维护子句池与存活标记。严格模式只接受 RUP，遇到 RAT 步骤判失败；`check_drat_rat` 用完整规则，取候选子句第一个文字为 pivot，与池中含其否定的每条子句求归结，归结式仍须为 RUP，池中没有含否定 pivot 的子句时判定成立。删除行按内容匹配，找不到匹配时忽略。

内部由 `CheckDb` 承担传播：每条子句监听两个文字，RUP 检查时只沿被置假文字对应的监听列表前进，单元子句作为 trail 的基座层不被回滚，删除步骤走子句哈希桶定位。子句数与变量数接近时该结构接近线性；变量极少、子句极多的病态实例（如深鸽巢证明）仍受每个文字的监听条数限制。

返回值 `false` 表示证明不可接受，**不代表公式可满足**——它只说明这份证明没有支撑 UNSAT 结论。

## MaxSAT

| 接口 | 签名 | 说明 |
| --- | --- | --- |
| `parse_wcnf` | `(text : String) -> Wcnf` | 解析 `p wcnf V C TOP` 格式；权重 ≥ TOP 为硬子句。宽容版本：不检查 header 与权重符号，配合 `wcnf_error` 使用 |
| `wcnf_error` | `(w : Wcnf) -> String?` | 实例能否被优化：缺 header、缺 TOP、软权重为负时给出原因，合法时返回 `None` |
| `maxsat_solve` | `(w : Wcnf, weight_cap : Int) -> Int raise` | 返回最小软代价；硬子句 UNSAT 时返回 `-1`；总软权重超过 `weight_cap` 时抛出异常 |
| `maxsat_core_bound` | `(w : Wcnf) -> Int` | 一个 unsat core 给出的代价下界（core 中最便宜的软子句必然被违反）；硬子句 UNSAT 返回 `-1`，软子句可全满足返回 `0` |
| `maxsat_encoding` | `(w : Wcnf, k : Int) -> Formula` | 「软代价 ≤ `k` 是否可行」对应的 CNF；确定性构造，同参数必得同公式 |
| `maxsat_bound_proof` | `(w : Wcnf, k : Int) -> String?` | 代价 `k` 不可达时返回 DRAT 证明，可达时返回 `None` |
| `verify_maxsat_bound` | `(w : Wcnf, k : Int, proof : String) -> Bool` | 重建 `maxsat_encoding(w, k)` 后重放证明，判定 `k` 是否真的不可达 |
| `maxsat_solution` | `(w : Wcnf, weight_cap : Int) -> (Array[Bool], Int)? raise` | 最优赋值与其代价；硬子句 UNSAT 返回 `None`；超权重上限抛出异常 |
| `maxsat_model` | `(w : Wcnf, weight_cap : Int) -> (Array[Bool], Int)?` | 同上但不抛异常：超权重上限也返回 `None`，首次调用不必写 `try` |
| `maxsat_oll` | `(w : Wcnf) -> Int` | 核心引导的最优代价，没有总权重上限；硬子句 UNSAT 返回 `-1` |
| `maxsat_oll_solution` | `(w : Wcnf) -> (Array[Bool], Int)?` | 同上并给出赋值；硬子句 UNSAT 返回 `None` |
| `maxsat_oll_result` | `(w : Wcnf, max_rounds : Int) -> OllOutcome` | 带轮预算的核心引导：`Solved(赋值, 代价)` / `Infeasible` / `Budgeted(下界, 上界)`；`max_rounds <= 0` 表示不限 |
| `maxsat_model_cost` | `(w : Wcnf, model : Array[Bool]) -> Int` | 按 WCNF 原文复算代价，硬子句被破坏返回 `-1` |
| `verify_maxsat_solution` | `(w : Wcnf, model : Array[Bool], claimed_cost : Int) -> Bool` | 声称的代价与复算结果是否一致 |

`maxsat_bound_proof` 与 `maxsat_solution` 是同一件事的两端：前者说明 `opt-1` 不可达，后者给出代价恰为 `opt` 的赋值。单看任一端都不能断言最优——只有「下界不可达 + 上界可达」都成立，`opt` 才是最优值。`maxsat_model_cost` 不依赖任何求解过程，只按 WCNF 累加，因此外部拿到 `v` 行后可以独立复算。

`maxsat_solve` 的二分区下端点由 `maxsat_core_bound` 起步：既然某个 core 里最便宜的一条必然被违反，比它更小的代价不可能达到，这部分判定可以直接跳过。0.6.8 起 `maxsat_oll` 补上完整核心引导：每轮取一个 core，按 `wmin` 记账，core 内每条软子句饱和这一层、剩余权重建新松弛文字，同一条子句被多个 core 命中也不重复收费；下界只增，同时把模型违反的软子句写成阻塞子句收紧上界，两界相接才收尾。它不建基数编码，因此没有 `weight_cap`。总软权重 ≤ 512 时会自动改走编码路径——均匀小权重大图上编码更快，结果一致。

`Wcnf` 的字段 `num_vars`、`top`、`hard`、`soft`、`weights` 可直接读取，便于调用方检查解析结果；`header_ok` 记录是否真的读到了带正 TOP 的 `p wcnf` 头（命令行用它决定拒绝还是继续）。

0.7.0 起核心引导可以设轮预算：`maxsat_oll_result(w, max_rounds)` 在预算内收敛时返回 `Solved`，硬子句本身不可满足返回 `Infeasible`，预算用尽返回 `Budgeted(lower, upper)`——下界只由 core 推进，上界从总软权重起步、每找到一个模型就下降，两者之差就是还差多少。一轮是一次 `solve_core` 加记账，对同一输入是确定性的，不是墙钟时限。均匀权重的大图上这条路径按层推进，20×20 加权网格给 20 轮预算会在 不到 10 ms 就返回 `lower= 2000 upper= 40000`，而不是无限跑下去。

## 命令行

```
moon run cmd/main -- solve "<DIMACS 文本>"
moon run cmd/main -- proof "<DIMACS 文本>"
moon run cmd/main -- verify "<DIMACS 文本>" "<DRAT 文本>"
moon run cmd/main -- maxsat "<WCNF 文本>" <weight_cap>
moon run cmd/main -- maxsat-cnf "<WCNF 文本>" <k>
moon run cmd/main -- maxsat-proof "<WCNF 文本>" <k>
moon run cmd/main -- verify-maxsat "<WCNF 文本>" <k> "<DRAT 文本>"
moon run cmd/main -- maxsat-verify "<WCNF 文本>"
moon run cmd/main -- maxsat-solution "<WCNF 文本>"
moon run cmd/main -- maxsat-oll "<WCNF 文本>"
moon run cmd/main -- maxsat-oll-budget "<WCNF 文本>" <rounds>
moon run cmd/main -- verify-solution "<WCNF 文本>" <cost> "<lits，如 1 -2 3 0>"
moon run cmd/main -- verify @examples/pigeonhole-3-2.cnf @proof.drat
```

命令行接受两种输入：内联文本（用 `;` 代替换行），或 `@路径`。后者是 0.7.6 起的：以 `@` 开头的参数按文件路径读取，读到的文本直接替换该参数，公式与证明两侧都适用，24 MB 的证明只能这样传。读盘由 `cmd/main` 用的官方 `moonbitlang/x/fs` 完成；库包本身不新增依赖，`moon.mod` 的 `deps` 仍为空。读不到文件时打印 `c error: cannot read file <path>` 并退出。不以 `@` 开头的路径参数照旧被挡下，提示改用 `@path` 或 `"$(cat file)"`——早期版本会把路径里的数字当成公式，静默给出一个错误结论。示例：

```
moon run cmd/main -- solve "p cnf 3 3;1 2 0;-1 0;-2 0"
```

输出沿用 DIMACS 求解器惯例：`s SATISFIABLE` / `s UNSATISFIABLE`，模型行以 `v` 开头，统计行以 `c` 开头。
