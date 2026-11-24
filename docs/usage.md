# 使用说明

本文覆盖安装、库调用、命令行、输出格式与常见问题。设计与实现细节见 [design.md](design.md)，接口逐项说明见 [api.md](api.md)。

## 环境要求

- MoonBit 0.1.x（`moon check` 可用），core 由工具链自带。
- 库无第三方依赖、无手写 FFI、无外部求解器；命令行可执行包 `cmd/main`（0.7.6 起）额外引入官方 `moonbitlang/x/fs`，只用于把 `@path` 参数读成字符串。四个后端只需标准构建工具链。
- native 后端需要本机有 C 编译器与链接器（Windows 需 MSVC，Linux/macOS 需 clang 或 gcc）。

## 安装

```bash
moon add 2227057182/moonbit-sat
```

包名导入为 `@moonbit_sat`。或从源码构建：

```bash
git clone https://github.com/2227057182/moonbit-sat.git
cd moonbit-sat
moon check --deny-warn
moon test
```

## 作为库使用

### 解析与求解

```moonbit
let f = @moonbit_sat.parse_dimacs("p cnf 2 2\n1 2 0\n-1 0\n")
let s = @moonbit_sat.Solver::new(f)
if s.solve([]) {
  println(s.model())        // Array[Bool]，下标即变量号
}
println(s.stats_string())   // decisions / propagations / conflicts / restarts / learnts / minimised
```

`parse_dimacs` 接受 `p cnf` 头；头里声明的变量数少于实际出现时自动扩大，不报错。

### 增量求解与假设

```moonbit
let s = @moonbit_sat.Solver::new(@moonbit_sat.parse_dimacs("p cnf 2 1\n1 2 0\n"))
assert_true(s.solve([]))
assert_false(s.solve([@moonbit_sat.lit_new(0, true), @moonbit_sat.lit_new(1, true)]))
assert_true(s.solve([@moonbit_sat.lit_new(0, true)]))
```

假设是临时决策：带假设的 UNSAT 会让求解器回退到 0 层，下一次调用不受影响；期间学习到的子句保留。

### 冲突预算

```moonbit
let s = @moonbit_sat.Solver::new(f)
match s.solve_with_budget([], 500) {
  Satisfiable => println("SAT")
  Unsatisfiable => println("UNSAT")
  Unknown => println("给不出结论，只花了 500 次冲突")
}
```

预算用尽时求解器回退到 0 层、重置传播指针，之后可以继续调用 `solve` 或换更大的预算重来，已学子句不会丢。这是给外部调度用的接口：宁可返回 `Unknown`，也不无限占用时间。

### 提取 unsat core

```moonbit
let s = @moonbit_sat.Solver::new(f)
let (sat, core) = s.solve_core([
  @moonbit_sat.lit_new(0, false),
  @moonbit_sat.lit_new(1, false),
])
if !sat {
  println(core)   // 这些假设放在一起就矛盾，单独拿它们再求解仍然是 UNSAT
}
```

core 不保证最小，只保证「子集 + 本身不可满足」。空数组意味着与假设无关，硬子句自己就不可满足。

### 证明与独立校验

```moonbit
let s = @moonbit_sat.Solver::new(f)
let p = s.enable_proof()
assert_false(s.solve([]))
assert_true(@moonbit_sat.verify_proof(f, p.text()))
```

`enable_proof()` 必须在求解前调用。证明文本是 DRAT 风格的行序列：每行 `lits 0` 表示新增一条子句，`d lits 0` 表示删除，最后一行为单独一个 `0`（空子句）。

`verify_proof` 不读取求解器状态：它把证明重放到「原公式 + 已验证子句」上，逐条做 RUP 复算，并要求结尾出现空子句。任何一步不成立或没有空子句都会返回 false。

需要接受外部工具产出的证明（其中的定义步骤可能不满足 RUP）时，改用 `verify_proof_rat`：RUP 不成立后再按 pivot 求归结，要求每个归结式仍是 RUP，池中没有含否定 pivot 的子句时直接成立。两种模式互不影响，strict 模式永远不会放松判定。

### 加权 MaxSAT

```moonbit
let w = @moonbit_sat.parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
let opt = @moonbit_sat.maxsat_solve(w, 512)
println(opt)   // 最小违约成本
```

WCNF 头格式为 `p wcnf <变量数> <子句数> <顶值>`，权重大于等于顶值的行是硬子句，其余是带权软子句。第二个参数是允许的总软权重上限；超过会直接报错，因为截断会给出错误的最优值。

要拿到最优赋值而不只是最优值：

```moonbit
match @moonbit_sat.maxsat_solution(w, 512) {
  Some((model, cost)) => {
    // 按 WCNF 原文复算，而不是相信求出来的数
    println(@moonbit_sat.maxsat_model_cost(w, model) == cost)      // true
    println(@moonbit_sat.verify_maxsat_solution(w, model, cost))   // true
  }
  None => println("hard clauses unsatisfiable")
}
```

`maxsat_bound_proof(w, opt - 1)` 证明 `opt - 1` 不可达，`maxsat_solution` 给出代价恰为 `opt` 的赋值；两者同时成立才叫最优。

`maxsat_solution` 会在超权重上限时抛异常，放在 `fn main` 里要写 `fn main raise`。不想处理异常就用 `maxsat_model`——同样的返回值，超上限时返回 `None`。初次接入建议直接用它：

```moonbit
fn main {
  let w = @moonbit_sat.parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  match @moonbit_sat.maxsat_model(w, 512) {
    Some((model, cost)) => println("cost=\{cost} verified=\{@moonbit_sat.verify_maxsat_solution(w, model, cost)}")
    None => println("no model (hard clauses unsat, or weight cap too small)")
  }
}
```

### 没有权重上限：核心引导

`maxsat_solve` 的第二参数是总软权重上限，超过直接报错。权重大的实例改用 `maxsat_oll`：它不建基数编码，因此没有上限。

```moonbit
let w = @moonbit_sat.parse_wcnf(wcnf_text)
let opt = @moonbit_sat.maxsat_oll(w)                     // 硬子句 UNSAT 时为 -1
let pair = @moonbit_sat.maxsat_oll_solution(w)           // Some((赋值, 代价)) 或 None
```

算法是核心引导：每轮用当前假设求一次核心，把 core 内最便宜的一层权重记进下界，core 里的软子句饱和这一层、剩余权重交给新的松弛文字；同时用「模型违反的软子句」写成阻塞子句收紧上界，直到上下界相接。总软权重 ≤ 512 时它会自动改走编码路径，因为均匀小权重的大图上编码快得多，结果完全一致。

`maxsat-oll` 子命令做同一件事，并顺带按 WCNF 原文复算模型代价：

```
moon run cmd/main -- maxsat-oll "<WCNF 文本>"
```

### 给核心引导加轮预算

均匀权重的大图上核心引导按层推进，轮数与最优值同量级，可能长时间不返回。`maxsat_oll_result(w, max_rounds)` 给一个轮数上限：

```moonbit
match @moonbit_sat.maxsat_oll_result(w, 50) {
  Solved(model, cost) => println("opt = \{cost}")
  Infeasible => println("hard clauses unsat")
  Budgeted(lower, upper) => println("at least \{lower}, at most \{upper}, not closed")
}
```

`max_rounds <= 0` 表示不设预算。`Budgeted` 同时给出已证明的下界与当前最好模型的上界，二者之差就是还剩多少要收；一轮是一次核心查询加记账，同一输入的轮数是确定的，不是墙钟时限。命令行对应 `maxsat-oll-budget "<WCNF>" <rounds>`：

```
c rounds= 20 lower= 2000 upper= 40000
s UNKNOWN (round budget exhausted)
```

### 变量编号约定

- DIMACS 文本里的变量从 1 开始，负号表示否定。
- `lit_new(v, neg)` 里的 `v` 从 0 开始，与 `model()` 的下标一致。
- 两个约定跨层时容易差一，README 的示例都按此对齐。

## 命令行

```bash
moon run cmd/main -- solve   "p cnf 3 2;1 2 0;-1 0"
moon run cmd/main -- proof   "p cnf 6 9;1 2 0;..."
moon run cmd/main -- verify  "p cnf 2 3;1 0;2 0;-1 -2 0" "1 0;2 0"
moon run cmd/main -- verify-rat "p cnf 2 3;1 0;2 0;-1 -2 0" "1 0;2 0"
moon run cmd/main -- maxsat  "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"
moon run cmd/main -- core    "p cnf 2 2;1 2 0;-1 -2 0" "1 2"
moon run cmd/main -- grid-wcnf 10 10
moon run cmd/main -- maxsat-cnf  "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 0
moon run cmd/main -- maxsat-proof "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 0
moon run cmd/main -- verify-maxsat "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 0 "<DRAT 文本>"
moon run cmd/main -- maxsat-verify "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"
moon run cmd/main -- maxsat-verify-external @examples/petersen-mwvc.wcnf 6 "<v 行>" @pet5.drat
moon run cmd/main -- maxsat-solution "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"
moon run cmd/main -- maxsat-oll-budget "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 50
moon run cmd/main -- verify-solution "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 1 "v 1 -2 0"
moon run cmd/main -- bench
moon run cmd/main -- bench-verify 9
moon run cmd/main -- proof    @examples/pigeonhole-3-2.cnf > p32.drat   # 从文件读公式，证明写进文件
moon run cmd/main -- verify   @examples/pigeonhole-3-2.cnf @p32.drat     # 再从文件验回来
```

参数中的 `;` 等价于换行，公式也可以直接内联。以 `@` 开头的参数按文件路径读取内容，`@examples/pigeonhole-3-2.cnf` 与 `"$(cat examples/pigeonhole-3-2.cnf)"` 等价，但不用经过 shell 展开。24 MB 的鸽巢 k=10 证明只能这样传：内联会撞上单个参数的 128 KB 上限（Linux `MAX_ARG_STRLEN`，Windows 约 32 KB）。直接写路径（不以 `@` 开头）仍会被挡下，提示改用 `@path` 或 `"$(cat file)"`，避免把路径里的数字当成公式、静默给出错误结论。读盘走官方 `moonbitlang/x/fs`；库本身不碰文件。

命令行的 `maxsat` / `maxsat-solution` / `maxsat-verify` 把总软权重上限固定为 512，没有第二个参数可调；要换上限就直接调库里的 `maxsat_solve(w, cap)`，或者用没有上限的 `maxsat-oll` / `maxsat-oll-budget`。

输入不合法时不再静默给结论，而是打印一行 `c error: …` 并以 0 退出：WCNF 缺少 `p wcnf <vars> <clauses> <top>`（或 top 不为正）、软权重为负、整数参数里含非数字、`bench-verify` 的 k 不在 6..10，都会这样被挡下。

输出遵循 SAT 竞赛的惯用格式：

| 子命令 | 输出 |
| --- | --- |
| `solve` | `s SATISFIABLE` + `v <文字> 0`，或仅 `s UNSATISFIABLE`（不给模型行） |
| `proof` | `s UNSATISFIABLE` + 证明行 + `0` |
| `verify` | `s VERIFIED` 或 `s PROOF-REJECTED`（严格 RUP） |
| `verify-rat` | 同上，但用 RUP + RAT 规则 |
| `maxsat` | `o <成本>` + `s OPTIMUM FOUND` |
| `core` | `s UNSATISFIABLE` + `c core= <文字> 0`（core 为空时打 `c core= (hard clauses alone are unsatisfiable)`）；或 `s SATISFIABLE` |
| `grid-wcnf` | 把 WCNF 实例文本打印到标准输出 |
| `maxsat-cnf <k>` | `p cnf …` 头 + 子句行：`maxsat_encoding(w, k)` 的 DIMACS，交给外部检查器用 |
| `maxsat-proof <k>` | `s UNSATISFIABLE (cost <= k unreachable)` + 证明行；或 `s SATISFIABLE (cost <= k achievable)` |
| `verify-maxsat` | `s VERIFIED` 或 `s PROOF-REJECTED`（重建同一编码后重放） |
| `maxsat-verify` | `o <成本>` + `c upper= <bool> lower= <bool>` + `s OPTIMALITY-VERIFIED`（上界赋值与 `opt-1` 的下界证明都要过）；任一端不过则 `s PROOF-REJECTED` |
| `maxsat-verify-external <opt> <lits> <DRAT>` | 同上两行输出，但赋值与证明由调用方提供：赋值按 WCNF 原文重算，证明在重建出来的编码上重放 |
| `maxsat-solution` | `o <成本>` + `v <文字> 0` + `s SOLUTION-VERIFIED`；硬子句 UNSAT 时 `s UNSATISFIABLE (hard clauses)` |
| `maxsat-oll` | 同 `maxsat-solution`，但走核心引导且没有总权重上限 |
| `maxsat-oll-budget <rounds>` | 收敛时同 `maxsat-oll`；预算用尽时 `c rounds= … lower= … upper= …` + `s UNKNOWN (round budget exhausted)` |
| `verify-solution` | `s SOLUTION-VERIFIED` 或 `s SOLUTION-REJECTED`（按 WCNF 重算给定的代价与赋值） |
| `bench` | 五行 `c bench vars=… clauses=… result=… decisions=… propagations=… conflicts=… minimised=…` |
| `bench-verify <k>` | `c verify k=… vars=… proof_lines=… sat=… result=VERIFIED` 或 `… REJECTED` |
| 任意 | 最后一行 `c decisions=… propagations=… conflicts=… restarts=… learnts=… minimised=…` |

## 外部复核最优性

前面两种 MaxSAT 验法都要求本仓库自己算出 `o` 与证明。要引入第三方工具，分三步：本仓库只导出编码，外部求解器出模型与证明，最后回到本仓库复算。

```bash
# 上界侧：代价 ≤ 6 的编码，可满足
moon run cmd/main -- maxsat-cnf @examples/petersen-mwvc.wcnf 6 > pet6.cnf
cadical pet6.cnf                       # 取 v 行里前 10 个变量（辅助变量忽略）
# 下界侧：代价 ≤ 5 的编码，不可满足，同时写出证明
moon run cmd/main -- maxsat-cnf @examples/petersen-mwvc.wcnf 5 > pet5.cnf
cadical --binary=false pet5.cnf pet5.drat
# 两端一起交回来
moon run cmd/main -- maxsat-verify-external @examples/petersen-mwvc.wcnf 6 "<v 行>" @pet5.drat
```

输出 `o 6` / `c upper= true lower= true` / `s OPTIMALITY-VERIFIED`。赋值按 WCNF 原文逐条重算代价（`maxsat_model_cost`），证明在 `maxsat_encoding(w, 5)` 重建出来的编码上逐条重放（`verify_proof`）；两条输入都不采信。

实测（native release，CaDiCaL 3.1.0）：

| 实例 | 外部证明 | 两端复算 | 自家 `maxsat-verify` |
| --- | --- | --- | --- |
| Petersen（10 顶点，`opt=6`） | 263 字节、14 行 | 5–10 ms | 5 ms |
| 10×10 网格（100 顶点，`opt=50`，编码 5150 变量） | 22331 字节、2835 行 | 62 ms | 约 345 ms |

Petersen 太小，两边的开销都在编码重建上，看不出差别；10×10 才拉开约 5 倍——`maxsat-verify` 要自己求两档最优值，复算只重放一份已有证明。两档的证明交给 `drat-trim` 也都是 `s VERIFIED`（0 RAT 引理）。注意 `proof` / `maxsat-proof` 的输出第一行是 `s UNSATISFIABLE …`，外部工具不认这一行，喂之前先 `grep -v '^s '` 过滤。

## 常见问题

**为什么证明被拒绝？**
常见的有三种：证明结尾没有单独的空子句；某条新增子句在当时的子句集上不是 RUP（`verify` 严格模式，用 `verify-rat` 再试 RAT）；子句里出现超出变量范围的编号。检查器遇到这些会返回 false 而不是跳过；第三条在 0.7.6 之前会索引越界 abort，现在与另两条一样只是判失败。

**为什么 MaxSAT 直接报错？**
总软权重（各软子句权重之和）超过调用方给出的上限。求解器会把每条软子句展开成若干个辅助变量，权重过大意味着辅助变量与子句数量按比例膨胀，报错比静默超时更有用。

**`moon build --target native` 失败？**
缺 C 编译器/链接器。Windows 需要安装 MSVC 并让 `moon` 找到它；其他后端（wasm、wasm-gc、js）不需要。

**求解器支持文件读写吗？**
库不做文件 IO：`parse_dimacs` / `parse_wcnf` 只吃文本，由调用方读入。命令行（0.7.6 起）提供 `@path`，把文件内容直接当参数，读盘由官方 `moonbitlang/x/fs` 完成，native / wasm-gc / js 三个后端都能构建；读不到时打印 `c error: cannot read file <path>` 并以 0 退出。

**大证明怎么验？**
检查器只解析 ASCII DRAT（每行一条子句）。二进制 DRAT（CaDiCaL 的默认二进制输出）需要先转成文本，例如 `cadical --binary=false`；直接喂二进制会被读成杂乱的小子句集并判 `PROOF-REJECTED`，而不是报格式错误。

两个输入都用 `@path` 交给命令行自己读：`verify @php-10.cnf @php-10.drat`。0.7.6 在 native 上实测 k=10 的 24.7 MB 证明（295345 行），整条命令 89 s 输出 `s VERIFIED`，含读盘与解析。手边没有文件时，`bench-verify <k>` 在同一进程里构造 `k` 鸽 `k-1` 洞实例、求解、取证明、校验并打印行数，不经过命令行。

**为什么没有并行和变量消除？**
两者都会改变四后端的一致性假设或增加实现风险，当前版本不做；见 [roadmap.md](roadmap.md)。
