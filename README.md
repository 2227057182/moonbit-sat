# moonbit-sat

纯 MoonBit 实现的 **CDCL SAT 求解器 + 可独立校验的 UNSAT 证明 + 加权 MaxSAT 优化**，
四个后端（wasm / wasm-gc / js / native）行为一致。

`moonbit-sat` 面向的是「判定—证明—优化」这条完整链路，而不是一份孤立的求解实现：

| 能力 | 说明 |
| --- | --- |
| CDCL 求解 | 两文字监听、1-UIP 学习子句、VSIDS 活动度、Luby 序列重启、子句库归约、相位保存 |
| 增量求解 | `solve(assumptions)` 可反复调用，带 assumption 的 UNSAT 不污染后续求解状态 |
| UNSAT core | `solve_core(assumptions)` 在 UNSAT 时返回一个本身不可满足的假设子集，可用来解释冲突，也给 MaxSAT 提供下界 |
| 冲突预算 | `solve_with_budget` 在给定冲突数后返回 `Unknown`，回退到 0 层，可继续求解 |
| UNSAT 证明 | 每个学习子句与最终空子句写入 DRAT 风格日志，可交给第三方检查器复算 |
| 独立检查器 | 项目自带 `check_drat` / `verify_proof`（RUP）与 `check_drat_rat` / `verify_proof_rat`（RUP + RAT），不信任求解器 |
| 加权 MaxSAT | WCNF 解析 + 松弛变量 + Sinz 顺序计数编码 + 二分求最优成本 |
| MaxSAT 最优性 | 下界侧 `maxsat_bound_proof` 导出「代价 `k` 不可达」的 DRAT 证明；上界侧 `maxsat_solution` 给出代价恰为 `opt` 的赋值，`maxsat_model_cost` 按 WCNF 原文复算；`maxsat-verify` 两端一起验 |
| 预处理 | `Formula::simplify` 去掉子句内重复文字、删除重言子句，并统计被删条数 |
| 四后端 | 不依赖 FFI、不依赖外部求解器，`preferred_target = "wasm"` 下与 native 同结果 |

全部证据（判定 / 证明 / 校验 / core / 加权 / 最优性两端 / 压力）的复现步骤与预期输出见 [docs/reproduce.md](docs/reproduce.md)。

## 安装

```bash
moon add 2227057182/moonbit-sat
```

或从源码构建：

```bash
git clone https://github.com/2227057182/moonbit-sat.git
cd moonbit-sat
moon check --deny-warn && moon test
```

### 最小可运行工程

新建目录，按这个顺序做（先 `moon add` 再写 import，可以避开索引未更新时的解析报错）：

```bash
mkdir sat-demo && cd sat-demo
printf 'name = "tmp/sat-demo"\nversion = "0.1.0"\n' > moon.mod
moon update
moon add 2227057182/moonbit-sat
```

`moon.pkg`：

```moonbit
import {
  "2227057182/moonbit-sat" @moonbit_sat
}
pkgtype(kind: "executable")
```

`main.mbt`（`maxsat_model` 不抛异常，普通 `fn main` 直接可用）：

```moonbit
fn main {
  // (x1 ∨ x2) ∧ ¬x1 ∧ ¬x2：两条软子句必有一条被违约，最优成本是 1
  let w = @moonbit_sat.parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  match @moonbit_sat.maxsat_model(w, 512) {
    Some((model, cost)) => {
      println("cost=\{cost}")                                                   // cost=1
      println("verified=\{@moonbit_sat.verify_maxsat_solution(w, model, cost)}")  // verified=true
    }
    None => println("hard clauses unsatisfiable")
  }
}
```

```bash
moon run .        # cost=1 / verified=true
```

`moon update` 靠 git 拉索引，报 `program not found: git` 时先装 git 或把 git 加进 PATH。

## 快速开始

```moonbit
// (a ∨ b) ∧ ¬a  ⇒  a=false, b=true
let f = @moonbit_sat.parse_dimacs("p cnf 2 2\n1 2 0\n-1 0\n")
let s = @moonbit_sat.Solver::new(f)
let proof = s.enable_proof()
if s.solve([]) {
  println(s.model())          // [false, true]
} else {
  // 证明：学习子句 + 空子句，DRAT 文本
  println(proof.text())
}
println(s.stats_string())     // decisions=… propagations=… conflicts=… learnts=…
```

### 增量求解与假设

```moonbit
let f = @moonbit_sat.parse_dimacs("p cnf 2 1\n1 2 0\n")
let s = @moonbit_sat.Solver::new(f)
assert_true(s.solve([]))
assert_false(s.solve([@moonbit_sat.lit_new(0, true), @moonbit_sat.lit_new(1, true)]))
assert_true(s.solve([@moonbit_sat.lit_new(0, true)]))  // 上一次 UNSAT 不影响这一次
```

### 独立校验证明

```moonbit
let f = @moonbit_sat.parse_dimacs(cnf_text)
let s = @moonbit_sat.Solver::new(f)
let p = s.enable_proof()
assert_false(s.solve([]))
assert_true(@moonbit_sat.verify_proof(f, p.text()))
```

`verify_proof` 不接触求解器状态：它按 DRAT 文本重放，每条新增子句都要在「原公式 + 已验证子句」上通过 RUP 复算，最后必须出现空子句。

`verify_proof_rat` 用完整规则：RUP 不成立时再试 RAT——取候选子句第一个文字为 pivot，池中每条含其否定的子句与候选子句求归结，归结式仍须是 RUP，池中没有含否定 pivot 的子句时直接成立。这条路径用于校验外部工具产出的证明；本项目求解器本身只产 RUP。

### 加权 MaxSAT

```bash
p wcnf 2 3 10
10 1 2 0     # 硬子句：a ∨ b
1 -1 0       # 软子句：¬a，权 1
1 -2 0       # 软子句：¬b，权 1
```

```moonbit
let w = @moonbit_sat.parse_wcnf(wcnf_text)
let opt = @moonbit_sat.maxsat_solve(w, 512)   // 总软权重上限 512
println(opt)                                   // 1
```

## CLI

```bash
moon run cmd/main -- solve  "p cnf 3 2;1 2 0;-1 0"        # SAT + 模型 + 统计
moon run cmd/main -- proof  "p cnf 6 9;1 2 0;..."         # UNSAT + DRAT 证明
moon run cmd/main -- verify "p cnf 2 3;1 0;2 0;-1 -2 0" "-1 0;0"   # 独立校验（RUP）
moon run cmd/main -- verify-rat "p cnf 2 3;1 0;2 0;-1 -2 0" "-1 0;0"  # 同一证明，RUP + RAT 规则
moon run cmd/main -- maxsat "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"
moon run cmd/main -- maxsat-cnf "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 0   # 打印「代价 ≤0」编码后的 CNF，交给外部检查器
moon run cmd/main -- maxsat-proof  "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 0   # 导出 k=0 不可达的证明
moon run cmd/main -- verify-maxsat "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 0 "$(cat proof)"  # 重建编码后校验
moon run cmd/main -- maxsat-verify "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"          # 上界赋值 + 下界证明一起验
moon run cmd/main -- maxsat-solution "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"        # 最优赋值 + 复算代价
moon run cmd/main -- verify-solution "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0" 1 "v 1 -2 0"   # 只核对导出的赋值
```

参数里的 `;` 会被当作换行，公式可以直接内联传参，无需临时文件。

## 生态里为什么还需要它

MoonBit 生态已有两个 SAT 相关包，能力边界与本项目并不重叠：

| | `AdUhTkJm/sat-solver` | `yf666888/moonsatkit` | **moonbit-sat** |
| --- | --- | --- | --- |
| 核心算法 | CDCL | DPLL | **CDCL（两监听 + 1-UIP + VSIDS + 重启 + 归约）** |
| 后端 | 仅 native | 四后端 | **四后端** |
| UNSAT 证明 | 无 | 无 | **DRAT 风格日志 + 自带独立检查器（RUP 与 RUP+RAT 两种模式）** |
| 加权优化 | 无 | 无 | **加权 partial MaxSAT（Sinz 编码 + 二分）** |
| 增量假设 | 不明确 | 有（`solve_with_assumptions`） | **有，且 assumption 冲突不污染状态** |

`clbbbb/lrat-check` 只有检查器、没有求解器；本项目两者同仓、可相互印证。

社区里做「判定 + 可验证证明 + 加权优化」的完整工具链此前是空白，这正是本项目的立足点，而不是「零依赖」或「统一 API」这类可替代的包装理由。

## 正确性证据

`moon test` 共 68 个测试，其中 11 类是硬证据：

1. **与暴力枚举对拍**：80 轮随机 3–5 变量公式，CDCL 的 SAT/UNSAT 结论与真值表枚举逐一比对，SAT 时还验证模型确实满足每条子句。
2. **证明自校验**：对随机 UNSAT 实例生成 DRAT 证明，再用 `verify_proof` 逐条 RUP 复算；同时有反例测试，确认非 RUP 步骤与缺失空子句都会被拒绝。
3. **MaxSAT 与暴力最优值对拍**：40 轮随机 WCNF，二分求得的最优成本与枚举所有赋值的最小成本一致。
4. **边界与退化输入**：空公式、空子句、重复文字、重言子句、变量越界、证明删除行、连续假设调用、MaxSAT 硬冲突与无软子句实例，各有独立测试；`simplify` 与原公式的结论还在 30 轮随机公式上逐一对拍。
5. **重启与预算**：Luby 序列前 16 项逐项固定，防止差一错误；0 预算在必然产生冲突的实例上返回 `Unknown`，随后同一求解器继续求解仍得到正确结论，确认中断后的状态可复用。
6. **最小化不削弱子句**：递归最小化删掉的字面必须让子句仍满足 RUP，5 鸽 4 洞实例的证明经独立检查器判定 `VERIFIED`；另有测试确认 `minimised > 0`，避免最小化静默失效。
7. **RAT 分支有正反两面**：在 `(x1∨x2)∧(¬x1∨x2)` 上加 `(x1)`，strict 必须拒绝、full 必须接受；在 `(¬x1∨x2)∧(¬x1∨x3)` 上加 `(x1)`，两种模式都必须拒绝，确认 RAT 不是「一律放行」。
8. **MaxSAT 下界证明可复算**：不可达下界能出证且校验通过、可达下界不出证、删掉空子句后被拒、同一证明挪到另一个 `k` 被拒、硬子句本身不可满足时证明仍可校验；另有 4 个真实实例在 native 上跑 `maxsat-verify` 全部 `OPTIMALITY-VERIFIED`。
9. **MaxSAT 上界可达**：最优赋值确实付出所声称的代价、声称代价偏大或偏小都被拒、破坏硬子句的赋值被拒、零代价实例仍给出可校验赋值、硬子句本身不可满足时返回 `None`；并在顶点覆盖实例上确认「上界 + 下界」两端同时成立才判最优。
10. **证明文本容错**：注释行（`c` / `s` / `o` 开头）被跳过而不是当成子句，把命令行打印的 `s` 与 `c …` 统计原样回喂给 `verify` 仍得到 `s VERIFIED`；只含注释的文本得到 `s PROOF-REJECTED`，不是崩溃。0.6.4 之前这里会 abort，三个测试守着。
11. **外部检查器交叉验证**：鸽巢 3–9 洞与三个加权实例的最优性下界共 10 个案例，交给 `drat-trim` 与 `lrat-check`（与本项目无共享代码的两个 C 检查器）复算，全部 `s VERIFIED` / `c VERIFIED`，且全部是 0 RAT 引理的纯 DRUP 证明。`BIG=1 bash tools/crosscheck.sh` 再追加鸽巢 10/9（295345 行，`drat-trim` 约 17s）与 20×20 网格下界（8622 行），12 个案例同样全绿。见 [docs/crosscheck.md](docs/crosscheck.md)。

```bash
moon check --deny-warn   # 0 warnings
moon test                # 68 passed
```

## 基准

```bash
moon run cmd/main -- bench
```

在固定的随机 3-SAT 阶梯上跑一遍，实例由内置线性同余发生器生成、种子写死，任何人可复现。输出决策、传播、冲突和最小化删掉的字面数：

| 变量 | 子句 | 结论 | 决策 | 传播 | 冲突 | 删除字面 |
| --- | --- | --- | --- | --- | --- | --- |
| 20 | 86 | SAT | 13 | 59 | 7 | 3 |
| 30 | 129 | UNSAT | 9 | 91 | 10 | 2 |
| 40 | 172 | SAT | 24 | 209 | 15 | 11 |
| 50 | 215 | SAT | 99 | 1008 | 76 | 44 |
| 60 | 258 | SAT | 108 | 1469 | 83 | 65 |

这是搜索量数据，不是墙钟耗时；也没有与 MiniSat、CaDiCaL 做过对比。本项目不声称性能领先，只声称链路完整且结论可被独立复算。

### 证明校验耗时

`bench-verify <k>` 在同一进程里构造 `k` 鸽 `k-1` 洞实例、求解、取证明、校验并打印行数——几千行的证明不可能作为命令行参数传进来（单个参数有 128KB 上限）。

```bash
moon run cmd/main -- bench-verify 9
```

native release 下实测，证明行数在改造前后完全相同：

| k | 变量 | 证明行数 | 全量扫描 | 两文字监听 | 扁平池（0.6.7） |
| --- | --- | --- | --- | --- | --- |
| 7 | 42 | 670 | 0.04s | 0.02s | 0.02s |
| 8 | 56 | 3942 | 0.66s | 0.16s | 0.14s |
| 9 | 72 | 40273 | 32.56s | 6.00s | 5.30s |
| 10 | 90 | 295345 | — | 435s | 366s |

检查器原先对每条新增子句都从头扫一遍整个池，行数 ×10 时耗时 ×50。改成两文字监听后，传播只沿被置假文字对应的监听列表走，k=9 提速 5.4 倍，结论仍是 `VERIFIED`。0.6.7 把子句池摊平成一维数组，端到端 k=9 从 6.00s 降到 5.30s、k=10 从 435s 降到 366s（其中求解约 239s，纯校验部分 196s → 127s）。同一条证明交给 `drat-trim` 只要约 17 s、`lrat-check` 约 0.7 s——我们仍慢约 7 倍，慢的是检查器的传播调度，不是证明本身，见 [docs/benchmarks.md](docs/benchmarks.md) 的「规模上限」。

## 范围边界

- 求解器只输出 **RUP** 步骤（CDCL 学习子句天然满足），不构造 RAT 步骤；检查器另有 RUP + RAT 模式（`verify-rat`），用于校验外部工具产出的证明。外部检查器复算这 10 个案例时统计到 **0 RAT 引理**，与这条边界一致。
- MaxSAT 用权重展开 + Sinz 编码，**总软权重**有上限（默认由调用方给出，示例 512），超出会明确报错而非静默降级；这是可计算性的诚实边界，不是功能缺失的掩饰。
- MaxSAT 最优性的上界只是「该赋值代价恰为 `opt`」，单独看不能排除更低的代价；与 `opt-1` 不可达的证明合起来才闭合最优性，所以 `maxsat-verify` 两端都要过。
- MaxSAT 最优性证明是对**扩展后的 CNF**（含 select 变量与 Sinz 计数变量）给出的，校验方必须用库内同一个 `maxsat_encoding` 重建公式。所以准确的说法是「可复算」而不是「不看编码也能独立验」；编码器是公开源码，不存在黑箱。这一点在 `docs/proof.md` 里单独说明。
- 最优性证明只覆盖「`k` 不可达」，不导出「`k` 可达」的模型。
- 预处理只做到子句内去重与重言消除（`Formula::simplify`），不含变量消除与子句自吸收；不含并行组合。这些是后续迭代项。

## 文档与示例

- [设计说明](docs/design.md)：数据结构、关键不变量，以及三次真实缺陷的成因与修法
- [使用说明](docs/usage.md)：安装、库调用、命令行、输出格式与常见问题
- [API 参考](docs/api.md)：公开接口逐项说明
- [实现来源与合规](docs/origin.md)：算法出处、无第三方代码、许可证与校验独立性
- [复现步骤](docs/reproduce.md)：从 clone 开始的七节证据与预期输出
- [外部交叉验证](docs/crosscheck.md)：把证明交给 `drat-trim` 与 `lrat-check` 复算的结果
- [本期新增](docs/november.md)：0.5.0 → 0.6.6 的实质变化与没做到的部分
- [路线图](docs/roadmap.md)：已完成与计划项
- [基准与对比](docs/benchmarks.md)：顶点覆盖实例、已知最优的依据与实测耗时
- [变更记录](CHANGELOG.md)
- [贡献指南](CONTRIBUTING.md)
- [示例实例](examples/README.md)：可满足、不可满足、加权、最小顶点覆盖样例及运行命令

## 开发

```bash
moon check --deny-warn
moon test
moon run cmd/main -- solve "p cnf 2 1;1 2 0"
```

## License

Apache-2.0
