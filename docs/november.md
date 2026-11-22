# 本期（十一月）新增了什么

对应验收条「工作有效：本期有实质新增」。这里只列十一月一日起进仓库的东西，按能力而非按提交排列；每条都给出可核对的位置。

## 从 0.5.0 到 0.6.6

| 能力 | 版本 | 之前的状态 | 现在的状态 | 可核对处 |
| --- | --- | --- | --- | --- |
| MaxSAT 下界可复算 | 0.6.2 | 最优值只是求解器的内部断言 | `maxsat_encoding` 显式构造「代价 ≤ k」的 CNF，`maxsat_bound_proof` 导出不可达的 DRAT，`verify_maxsat_bound` 重建后重放 | `docs/proof.md`「MaxSAT 最优性的证明」 |
| MaxSAT 上界可达 | 0.6.3 | 只有下界，缺「达到 opt 的赋值」 | `maxsat_solution` / `maxsat_model_cost` / `verify_maxsat_solution`；`maxsat-verify` 升级为 `c upper=` 与 `c lower=` 双端校验 | `maxsat_model_wbtest.mbt`、`docs/proof.md`「上界」 |
| 外部可复核赋值 | 0.6.3 | 无 | `verify-solution <wcnf> <cost> <lits>` 只吃外部给的代价与赋值，按 WCNF 原文重算 | `docs/usage.md` 命令行表 |
| 首次接入不需要处理异常 | 0.6.4 | `maxsat_solution` 会 raise，`fn main` 里不可直接调用 | `maxsat_model` 同签名但不抛异常；README 给出可粘贴的最小工程 | `README.md`「最小可运行工程」 |
| 真实实例与已知最优 | 0.6.0–0.6.1 | 只有随机对拍 | Petersen 与 4×5 网格的 MWVC 实例、`grid-wcnf` 生成器、`docs/benchmarks.md` 写明已知最优的独立依据 | `examples/`、`docs/benchmarks.md` |
| 证明交给外部检查 | 0.6.5 | 只能用自己的检查器复算，外人拿不到「公式」 | `maxsat-cnf` 导出编码后的 CNF；`tools/crosscheck.sh` 用 `drat-trim` 与 `lrat-check` 复算 10 个案例，全部 `s VERIFIED` / `c VERIFIED`，且全是 0 RAT 引理的纯 DRUP | `docs/crosscheck.md` |
| 更大实例 | 0.6.6 | 最大 100 变量 | 20×20 网格（400 变量）`o 200`，König 定理独立佐证；鸽巢 k=10 的 295345 行证明经 `drat-trim` 与 `lrat-check` 复算 | `docs/benchmarks.md`「规模上限」 |
| 检查器吞吐 | 0.5.0 | 逐条全池扫描，k=9 需 32.56s | 两文字监听增量传播，k=9 降到 5.96s（5.5×） | `docs/proof.md`、`CHANGELOG.md` 0.5.0 |

## 量化

- 测试：37 → 68，wasm / js / native 同结果，`moon check --deny-warn` 零告警。
- 命令：8 → 15 个子命令（新增 `grid-wcnf`、`maxsat-cnf`、`maxsat-proof`、`verify-maxsat`、`maxsat-verify`、`maxsat-solution`、`verify-solution`）。
- 文档：`docs/` 共 11 篇（新增 `benchmarks.md`、`proof.md`、`november.md`、`reproduce.md`、`crosscheck.md`、`申报书.md`）。
- 提交：十一月一日至二十二日共 76 次，其中 0.6.6 发布前 73 次、其后 3 次是文档措辞修订，包含一次已合并的外部 PR 与一个关闭的 Issue（#6，记录 MaxSAT 最优性证明这项工作）。
- 发布：Mooncakes 0.5.0 → 0.6.6，每次 `build=success`，0.6.4、0.6.5、0.6.6 各有 tag 与 GitHub Release。

## 没有做到的

- 完整 OLL/WPM1 core-guided MaxSAT：只有 core 提取与下界收紧，权重拆解未实现。
- 没有与 SAT Competition 的官方证明集对拍：那些证明由别的求解器产生，属于「用本项目检查器读外部证明」，与「外部工具验本项目证明」是两件事。
- 检查器 k=10（295345 行）仍需约 350s，瓶颈是每个文字挂的监听条数。
- 最大实例 400 变量（20×20 网格；鸽巢 k=10 是 90 变量、295345 行证明），未与工业求解器同数据集比较。

这些边界在 `docs/roadmap.md` 与申报书的「范围边界」里都写着，没有包装成已完成。
