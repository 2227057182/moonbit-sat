# 使用说明

本文覆盖安装、库调用、命令行、输出格式与常见问题。设计与实现细节见 [design.md](design.md)，接口逐项说明见 [api.md](api.md)。

## 环境要求

- MoonBit 0.1.x（`moon check` 可用），core 由工具链自带。
- 无第三方依赖、无 FFI、无外部求解器；四个后端只需标准构建工具链。
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
moon run cmd/main -- bench
moon run cmd/main -- bench-verify 9
```

参数中的 `;` 等价于换行，公式直接内联，不需要临时文件（MoonBit core 目前没有文件系统模块）。

输出遵循 SAT 竞赛的惯用格式：

| 子命令 | 输出 |
| --- | --- |
| `solve` | `s SATISFIABLE` + `v <文字> 0`，或 `s UNSATISFIABLE` + `-1 0` |
| `proof` | `s UNSATISFIABLE` + 证明行 + `0` |
| `verify` | `s VERIFIED` 或 `s PROOF-REJECTED`（严格 RUP） |
| `verify-rat` | 同上，但用 RUP + RAT 规则 |
| `maxsat` | `o <成本>` + `s OPTIMUM FOUND` |
| `bench` | 五行 `c bench vars=… clauses=… result=… decisions=… propagations=… conflicts=… minimised=…` |
| `bench-verify <k>` | `c verify k=… vars=… proof_lines=… sat=… result=VERIFIED` 或 `… REJECTED` |
| 任意 | 最后一行 `c decisions=… propagations=… conflicts=… restarts=… learnts=… minimised=…` |

## 常见问题

**为什么证明被拒绝？**
三种情况最常见：证明结尾没有单独的空子句；某条新增子句在当时的子句集上不是 RUP（`verify` 严格模式，用 `verify-rat` 再试 RAT）；子句里出现超出变量范围的编号。检查器遇到这些会返回 false 而不是跳过。

**为什么 MaxSAT 直接报错？**
总软权重（各软子句权重之和）超过调用方给出的上限。求解器会把每条软子句展开成若干个辅助变量，权重过大意味着辅助变量与子句数量按比例膨胀，报错比静默超时更有用。

**`moon build --target native` 失败？**
缺 C 编译器/链接器。Windows 需要安装 MSVC 并让 `moon` 找到它；其他后端（wasm、wasm-gc、js）不需要。

**求解器支持文件读写吗？**
库与命令行都不做文件 IO，因为 MoonBit core 当前没有 fs 模块。需要读文件时，在调用方读入文本再传给 `parse_dimacs` / `parse_wcnf`。

**为什么大证明要用 `bench-verify` 而不是 `verify`？**
操作系统对单个命令行参数有上限（Linux 128KB、Windows 约 32KB），一万行的证明就会 `Argument list too long`。`bench-verify <k>` 在同一进程里构造 `k` 鸽 `k-1` 洞实例、求解、取证明、校验并打印行数，不经过命令行。检查外部文件时走库 API `verify_proof(formula, text)`，把文本读进来再传即可。

**为什么没有并行和变量消除？**
两者都会改变四后端的一致性假设或增加实现风险，当前版本不做；见 [roadmap.md](roadmap.md)。
