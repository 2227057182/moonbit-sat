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
| `Solver::model` | `() -> Array[Bool]` | 每个变量的取值，未赋值变量按 `false` 处理 |
| `Solver::add_clause` | `(lits : Array[Lit]) -> Bool` | 增量追加约束（回退到 0 层，保留学习子句）；返回 `false` 表示公式已 UNSAT |
| `Solver::value_lit` | `(l : Lit) -> Int` | `1` 为真、`0` 为假、`-1` 为未赋值 |
| `Solver::decision_level` | `() -> Int` | 当前决策层 |
| `Solver::stats_string` | `() -> String` | 一行统计：决策数、传播数、冲突数、重启数、学习子句数 |

`assumptions` 的语义：按顺序在 0 层之上做临时决策。任一假设冲突时返回 `false`，但**不会**让求解器进入永久 UNSAT 状态，后续 `solve([])` 仍然有效。

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
| `verify_proof` | `(formula : Formula, proof_text : String) -> Bool` | `parse_drat` + `check_drat` 的组合 |

`check_drat` 独立于求解器：它自己维护子句池与存活标记。只接受 RUP，遇到 RAT 步骤会判失败。删除行按内容匹配，找不到匹配时忽略。

返回值 `false` 表示证明不可接受，**不代表公式可满足**——它只说明这份证明没有支撑 UNSAT 结论。

## MaxSAT

| 接口 | 签名 | 说明 |
| --- | --- | --- |
| `parse_wcnf` | `(text : String) -> Wcnf` | 解析 `p wcnf V C TOP` 格式；权重 ≥ TOP 为硬子句 |
| `maxsat_solve` | `(w : Wcnf, weight_cap : Int) -> Int raise` | 返回最小软代价；硬子句 UNSAT 时返回 `-1`；总软权重超过 `weight_cap` 时抛出异常 |

`Wcnf` 的字段 `num_vars`、`top`、`hard`、`soft`、`weights` 可直接读取，便于调用方检查解析结果。

## 命令行

```
moon run cmd/main -- solve "<DIMACS 文本>"
moon run cmd/main -- proof "<DIMACS 文本>"
moon run cmd/main -- verify "<DIMACS 文本>" "<DRAT 文本>"
moon run cmd/main -- maxsat "<WCNF 文本>" <weight_cap>
```

命令行不接受文件 IO（MoonBit core 目前没有文件系统模块），文本参数中用 `;` 代替换行。示例：

```
moon run cmd/main -- solve "p cnf 3 3;1 2 0;-1 0;-2 0"
```

输出沿用 DIMACS 求解器惯例：`s SATISFIABLE` / `s UNSATISFIABLE`，模型行以 `v` 开头，统计行以 `c` 开头。
