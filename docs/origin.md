# 实现来源与开源合规

本文件说明代码来源、参考的方法出处与许可证，用于回应「开源合规：使用认可的开源许可证，并说明移植或参考来源」这一项。

## 许可证

Apache-2.0，全文见仓库根目录的 [LICENSE](../LICENSE)。允许商用与修改，需保留版权与许可声明。

## 代码来源

- 仓库内全部 MoonBit 代码为本项目原创编写，未复制任何第三方项目的源文件，也未做机械翻译式的移植。
- `moon.mod` 没有 `deps` 字段：不依赖任何第三方 MoonBit 包。
- 没有 FFI 调用，不链接、不调用 MiniSat、CaDiCaL、Kissat 等外部求解器；求解、检查、优化都在 MoonBit 内完成。
- 没有引入 GPL/AGPL 代码，因此不存在许可证传染问题。

## 方法参考（公开算法，非代码复制）

实现过程中的算法依据均来自公开发表的论文、技术报告与格式规范：

| 内容 | 出处 |
| --- | --- |
| CDCL 主循环、两文字监听传播、1-UIP 冲突分析与回跳 | M. Eén, N. Sörensson, *An Extensible SAT-solver*, SAT 2003；MiniSat 的实现说明是公开材料 |
| VSIDS 变量活跃度与衰减 | M. Moskewicz et al., *Chaff: Engineering an Efficient SAT Solver*, DAC 2001 |
| 相位保存（phase saving） | K. Pipatsrisawat, A. Darwiche, *A Lightweight Component Caching Scheme*, 2007 |
| 按 LBD 与活跃度归约学习子句 | G. Audemard, L. Simon, *Predicting Learnt Clauses Quality in Modern SAT Solvers*, IJCAI 2009 |
| Luby 重启序列 | M. Luby, A. Sinclair, D. Zuckerman, *Optimal Speedup of Las Vegas Algorithms*, 1993；重启调度方式同 MiniSat |
| DRAT 证明格式与 RUP 校验 | DRAT 证明格式规范（Heule 等）与 SAT 竞赛的 proof checking 惯例 |
| WCNF 格式与顺序计数器编码 | SAT/MaxSAT 竞赛格式；N. Sinz, *Towards an Optimal CNF Encoding of Boolean Cardinality Constraints*, CP 2005 |

这些是方法与公式层面的参考：本项目按 MoonBit 的数据结构重新组织（字面用整数编码、子句用可变数组、监听表用数组桶），没有对应的参考实现代码进入仓库。

## 证明校验的独立性

`checker.mbt` 不引用 `solver.mbt`，也不读取求解器的任何内部状态；两者只共享 `lit.mbt` 的字面编码与 `cnf.mbt` 的解析层。校验器只依赖「原公式文本 + 证明文本」，因此换一个求解器产出的 RUP 证明同样能被它检查，反之亦然。

## 测试数据的来源

- 随机实例由测试内置的线性同余发生器生成，随机种子写死在测试里，不依赖外部数据集。
- `examples/` 下的实例全部手工构造或由命令行生成，不含第三方数据：
  - `simple-sat.cnf`、`pigeonhole-3-2.cnf`：教学用的小实例（后者是 3 鸽 2 洞）。
  - `scheduling.wcnf`：加权排班，硬子句写约束、软子句写偏好。
  - `petersen-mwvc.wcnf`、`grid-mwvc.wcnf`：Petersen 图与 4×5 网格的最小顶点覆盖（MWVC），由 `grid-wcnf` 子命令生成的同族实例可任意规模复现。
- 实例的已知最优值都有独立依据，不是由本求解器自报：Petersen 靠「5 顶点覆盖要求补集是独立集、而独立数为 4」，网格靠 König 定理（二分图最小顶点覆盖 = 最大匹配），详见 `docs/benchmarks.md`。

## 贡献与版权

仓库提交历史即贡献记录。如需在论文或课程中引用本项目，请引用仓库地址与版本号。
