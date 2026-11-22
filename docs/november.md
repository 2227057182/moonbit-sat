# 本期（十一月）新增了什么

对应验收条「工作有效：本期有实质新增」。这里只列十一月一日起进仓库的东西，按能力而非按提交排列；每条都给出可核对的位置。

## 从 0.5.0 到 0.6.8

| 能力 | 版本 | 之前的状态 | 现在的状态 | 可核对处 |
| --- | --- | --- | --- | --- |
| MaxSAT 下界可复算 | 0.6.2 | 最优值只是求解器的内部断言 | `maxsat_encoding` 显式构造「代价 ≤ k」的 CNF，`maxsat_bound_proof` 导出不可达的 DRAT，`verify_maxsat_bound` 重建后重放 | `docs/proof.md`「MaxSAT 最优性的证明」 |
| MaxSAT 上界可达 | 0.6.3 | 只有下界，缺「达到 opt 的赋值」 | `maxsat_solution` / `maxsat_model_cost` / `verify_maxsat_solution`；`maxsat-verify` 升级为 `c upper=` 与 `c lower=` 双端校验 | `maxsat_model_wbtest.mbt`、`docs/proof.md`「上界」 |
| 外部可复核赋值 | 0.6.3 | 无 | `verify-solution <wcnf> <cost> <lits>` 只吃外部给的代价与赋值，按 WCNF 原文重算 | `docs/usage.md` 命令行表 |
| 首次接入不需要处理异常 | 0.6.4 | `maxsat_solution` 会 raise，`fn main` 里不可直接调用 | `maxsat_model` 同签名但不抛异常；README 给出可粘贴的最小工程 | `README.md`「最小可运行工程」 |
| 真实实例与已知最优 | 0.6.0–0.6.1 | 只有随机对拍 | Petersen 与 4×5 网格的 MWVC 实例、`grid-wcnf` 生成器、`docs/benchmarks.md` 写明已知最优的独立依据 | `examples/`、`docs/benchmarks.md` |
| 证明交给外部检查 | 0.6.5 | 只能用自己的检查器复算，外人拿不到「公式」 | `maxsat-cnf` 导出编码后的 CNF；`tools/crosscheck.sh` 用 `drat-trim` 与 `lrat-check` 复算 10 个案例，全部 `s VERIFIED` / `c VERIFIED`，且全是 0 RAT 引理的纯 DRUP（0.6.6 起 `BIG=1` 追加两个大实例，共 12 个） | `docs/crosscheck.md` |
| 更大实例 | 0.6.6 | 最大 100 变量 | 20×20 网格（400 变量）`o 200`，König 定理独立佐证；鸽巢 k=10 的 295345 行证明经 `drat-trim` 与 `lrat-check` 复算 | `docs/benchmarks.md`「规模上限」 |
| 检查器吞吐 | 0.5.0 | 逐条全池扫描，k=9 校验 32.56s | 两文字监听（5.96s）；0.6.7 摊平子句池后 k=9 2.5s、k=10 196s→127s | `docs/proof.md`、`CHANGELOG.md` |
| 加权 MaxSAT 无总权重上限 | 0.6.8 | 总软权重超过 `weight_cap` 直接抛错 | 核心引导 `maxsat_oll`：core 驱动下界 + 阻塞式上界，不建基数编码；权重 100 的 Petersen 7ms 得 `o 600`，同一实例 `maxsat` 抛上限错误 | `maxsat.mbt`、`maxsat_oll_wbtest.mbt`、`docs/api.md` |

## 量化

- 测试：37 → 77，wasm / js / native 同结果，`moon check --deny-warn` 零告警。
- 命令：8 → 16 个子命令（新增 `grid-wcnf`、`maxsat-cnf`、`maxsat-proof`、`verify-maxsat`、`maxsat-verify`、`maxsat-solution`、`maxsat-oll`、`verify-solution`）。
- 文档：`docs/` 共 11 篇（新增 `benchmarks.md`、`proof.md`、`november.md`、`reproduce.md`、`crosscheck.md`、`申报书.md`）。
- 提交：十一月一日至二十二日截至 0.6.8 发布共 82 次（0.6.7 发布前 78 次），包含一次已合并的外部 PR 与一个关闭的 Issue（#6，记录 MaxSAT 最优性证明这项工作）。
- 发布：Mooncakes 0.5.0 → 0.6.8，每次 `build=success`（0.6.8 已在 registry 显示 `latest_version` 为 0.6.8），0.6.4 起每个版本都有 tag 与 GitHub Release。

## 没有做到的

- 核心引导路径在均匀权重的大图上按层推进，每轮一层：20×20 加权网格没有跑完，大均匀权重实例仍应走编码路径。
- 没有与 SAT Competition 的官方证明集对拍：那些证明由别的求解器产生，属于「用本项目检查器读外部证明」，与「外部工具验本项目证明」是两件事。
- 检查器 k=10（295345 行）校验 127s，仍比 `drat-trim` 慢约 7 倍，瓶颈在传播调度。
- 最大实例 400 变量（20×20 网格；鸽巢 k=10 是 90 变量、295345 行证明），未与工业求解器同数据集比较。

这些边界在 `docs/roadmap.md` 与申报书的「范围边界」里都写着，没有包装成已完成。
