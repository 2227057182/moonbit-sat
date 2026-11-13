# moonbit-sat

纯 MoonBit 实现的 **CDCL SAT 求解器 + 可独立校验的 UNSAT 证明 + 加权 MaxSAT 优化**，
四个后端（wasm / wasm-gc / js / native）行为一致。

`moonbit-sat` 面向的是「判定—证明—优化」这条完整链路，而不是一份孤立的求解实现：

| 能力 | 说明 |
| --- | --- |
| CDCL 求解 | 两文字监听、1-UIP 学习子句、VSIDS 活动度、重启、子句库归约、相位保存 |
| 增量求解 | `solve(assumptions)` 可反复调用，带 assumption 的 UNSAT 不污染后续求解状态 |
| UNSAT 证明 | 每个学习子句与最终空子句写入 DRAT 风格日志，可交给第三方检查器复算 |
| 独立检查器 | 项目自带 `check_drat` / `verify_proof`，逐条 RUP 复算，不信任求解器 |
| 加权 MaxSAT | WCNF 解析 + 松弛变量 + Sinz 顺序计数编码 + 二分求最优成本 |
| 预处理 | `Formula::simplify` 去掉子句内重复文字、删除重言子句，并统计被删条数 |
| 四后端 | 不依赖 FFI、不依赖外部求解器，`preferred_target = "wasm"` 下与 native 同结果 |

## 安装

```bash
# 从 GitHub 获取（Mooncakes 发布后即可 `moon add 2227057182/moonbit-sat`）
git clone https://github.com/2227057182/moonbit-sat.git
cd moonbit-sat
moon check --deny-warn && moon test
```

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
moon run cmd/main -- verify "p cnf 2 3;1 0;2 0;-1 -2 0" "-1 0;0"   # 独立校验
moon run cmd/main -- maxsat "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"
```

参数里的 `;` 会被当作换行，公式可以直接内联传参，无需临时文件。

## 生态里为什么还需要它

MoonBit 生态已有两个 SAT 相关包，能力边界与本项目并不重叠：

| | `AdUhTkJm/sat-solver` | `yf666888/moonsatkit` | **moonbit-sat** |
| --- | --- | --- | --- |
| 核心算法 | CDCL | DPLL | **CDCL（两监听 + 1-UIP + VSIDS + 重启 + 归约）** |
| 后端 | 仅 native | 四后端 | **四后端** |
| UNSAT 证明 | 无 | 无 | **DRAT 风格日志 + 自带独立 RUP 检查器** |
| 加权优化 | 无 | 无 | **加权 partial MaxSAT（Sinz 编码 + 二分）** |
| 增量假设 | 不明确 | 有（`solve_with_assumptions`） | **有，且 assumption 冲突不污染状态** |

`clbbbb/lrat-check` 只有检查器、没有求解器；本项目两者同仓、可相互印证。

社区里做「判定 + 可验证证明 + 加权优化」的完整工具链此前是空白，这正是本项目的立足点，而不是「零依赖」或「统一 API」这类可替代的包装理由。

## 正确性证据

`moon test` 共 24 个测试，其中三类是硬证据：

1. **与暴力枚举对拍**：80 轮随机 3–5 变量公式，CDCL 的 SAT/UNSAT 结论与真值表枚举逐一比对，SAT 时还验证模型确实满足每条子句。
2. **证明自校验**：对随机 UNSAT 实例生成 DRAT 证明，再用 `verify_proof` 逐条 RUP 复算；同时有反例测试，确认非 RUP 步骤与缺失空子句都会被拒绝。
3. **MaxSAT 与暴力最优值对拍**：40 轮随机 WCNF，二分求得的最优成本与枚举所有赋值的最小成本一致。
4. **边界与退化输入**：空公式、空子句、重复文字、重言子句、变量越界、证明删除行、连续假设调用、MaxSAT 硬冲突与无软子句实例，各有独立测试；`simplify` 与原公式的结论还在 30 轮随机公式上逐一对拍。

```bash
moon check --deny-warn   # 0 warnings
moon test                # 24 passed
```

## 范围边界

- 证明只输出 **RUP** 步骤（CDCL 学习子句天然满足），不构造 RAT 步骤；检查器遇到非 RUP 步骤会拒绝而不是放过。
- MaxSAT 用权重展开 + Sinz 编码，**总软权重**有上限（默认由调用方给出，示例 512），超出会明确报错而非静默降级；这是可计算性的诚实边界，不是功能缺失的掩饰。
- 预处理只做到子句内去重与重言消除（`Formula::simplify`），不含变量消除与子句自吸收；不含并行组合。这些是后续迭代项。

## 文档与示例

- [设计说明](docs/design.md)：数据结构、关键不变量，以及三次真实缺陷的成因与修法
- [API 参考](docs/api.md)：公开接口逐项说明
- [路线图](docs/roadmap.md)：已完成与计划项
- [变更记录](CHANGELOG.md)
- [贡献指南](CONTRIBUTING.md)
- [示例实例](examples/README.md)：可满足、不可满足、加权三个样例及运行命令

## 开发

```bash
moon check --deny-warn
moon test
moon run cmd/main -- solve "p cnf 2 1;1 2 0"
```

## License

Apache-2.0
