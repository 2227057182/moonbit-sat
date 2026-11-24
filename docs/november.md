# 本期（十一月）新增了什么

对应验收条「工作有效：本期有实质新增」。这里只列十一月一日起进仓库的东西，按能力而非按提交排列；每条都给出可核对的位置。

## 从 0.5.0 到 0.7.7

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
| 核心引导可设轮预算 | 0.7.0 | 不收敛的实例只能干等，没有任何出口 | `maxsat_oll_result(w, rounds)` 返回 `Solved` / `Infeasible` / `Budgeted(下界, 上界)`；20×20 加权网格给 20 轮在 不到 10ms 就返回 `lower= 2000 upper= 40000`；另有一个三条三元超边的加权超图实例与编码路径对拍（`o 200`），覆盖不是顶点覆盖的形态 | `maxsat.mbt`、`maxsat_oll_wbtest.mbt`、`cmd/main/main.mbt`、`docs/usage.md` |
| 读入外部求解器的证明 | 0.7.1 | 检查器只被自己的求解器喂过证明，`verify-rat` 的读入路径没有真实样本 | CaDiCaL 3.1.0 的鸽巢 6/5（235 行、156 添加 79 删除）与 7/6（1846 行）证明原样通过 `verify` 与 `verify-rat`，`drat-trim` 结论一致；删掉末尾空子句即被拒绝。两份证明已内联成测试，复跑不需装 CaDiCaL | `external_proof_wbtest.mbt`、`docs/crosscheck.md`「反方向」 |
| 输入面加固 | 0.7.4 | 负权重 WCNF 让 `maxsat` 直接 abort；缺 header 的实例把所有软子句当硬子句；非数字参数读成 0；`bench-verify 11` 静默测 k=8 | 新增 `wcnf_error`，9 处 CLI 解析后检查、5 处整数参数检查，全部改成一行 `c error:` 并以 0 退出；库层面负权重 `raise`、负 k 返回空子句；5 个新测试（82 → 87） | `maxsat.mbt`、`cmd/main/main.mbt`、`wcnf_guard_wbtest.mbt`、`docs/usage.md` |
| 外部复核最优性 | 0.7.7 | `maxsat-verify` 只能验自己算出的那一对 `o` 与证明，第三方没有复核入口 | `maxsat-verify-external` 接受外部赋值与外部证明，`opt-1` 的 DRAT 在重建编码上重放；CaDiCaL 3.1.0 实测 Petersen 3 ms、10×10 网格 66 ms，两份证明 `drat-trim` 也 VERIFIED；3 个测试（90 → 93） | `maxsat.mbt`、`cmd/main/main.mbt`、`maxsat_external_wbtest.mbt` |
| 命令行读文件 | 0.7.6 | 公式与证明只能内联，单个参数 128 KB 上限，24 MB 的 k=10 证明没法通过命令行校验 | 以 `@` 开头的参数按路径读盘，`verify @cnf @drat` 直接可用；native 上 k=10 的 24.7 MB 证明整条命令 89 s 得 `s VERIFIED`（含读盘与解析）；读不到时 `c error: cannot read file <path>`；内联调用完全不变 | `cmd/main/main.mbt`、`cmd/main/moon.pkg`、`docs/usage.md` |
| 证明越界不再崩溃 | 0.7.6 | 证明引用公式未声明的变量（`999 0` 配两变量公式）会索引越界 abort | `steps_in_range` 前置扫描，越界判 `s PROOF-REJECTED`；24 MB 证明多 0.6% 时间；3 个新测试（87 → 90） | `checker.mbt`、`checker_guard_wbtest.mbt` |
| 裁剪式复算的评估 | 0.7.5 | roadmap 记着「k=10 时 drat-trim 只验 172527 条」，把它当成与本检查器 4–7 倍差距的主要来源 | 用临时 reason 探针实测核心闭包：k=9 是 93%、k=10 是 87%，只有 k=8 能裁掉 65%；带探针开销 6%，真正贵的两档省不到 10 s，跳过验证还要在时序约束下还原池，判定不做 | `docs/proof.md`、`docs/roadmap.md` |

## 量化

- 测试：37 → 93，wasm / js / native 同结果，`moon check --deny-warn` 零告警。
- 命令：8 → 18 个子命令（新增 `grid-wcnf`、`maxsat-cnf`、`maxsat-proof`、`verify-maxsat`、`maxsat-verify`、`maxsat-solution`、`maxsat-oll`、`maxsat-oll-budget`、`verify-solution`）。
- 文档：`docs/` 共 11 篇（新增 `benchmarks.md`、`proof.md`、`november.md`、`reproduce.md`、`crosscheck.md`、`申报书.md`）。
- 提交：十一月一日至二十三日共 96 次（0.6.7 发布前 78 次），包含一次已合并的外部 PR 与一个关闭的 Issue（#6，记录 MaxSAT 最优性证明这项工作）。
- 发布：Mooncakes 0.5.0 → 0.7.7，每次 `build=success`（0.6.9 与 0.7.0 均已在 registry 显示 `latest_version`），0.6.4 起每个版本都有 tag 与 GitHub Release。

## 没有做到的

- 核心引导的 at-least 基数网络没有实现：三组实例实测下界每轮只涨 `wmin`，at-least-k 的 k 恒为 1，形式上的补齐不改变任何数字（推导见 `docs/proof.md`，这是主动放弃而非遗漏）。
- 核心引导路径在均匀权重的大图上按层推进，每轮一层：20×20 加权网格仍没有跑到收敛，只能靠轮预算带界返回（`lower= 2000 upper= 40000`）；大均匀权重实例仍应走编码路径。
- 外部证明只覆盖一个求解器、两个小实例：CaDiCaL 3.1.0 对鸽巢 6/5 与 7/6 写出的都是纯 DRUP，`verify-rat` 的 RAT 分支没有真实外部样本；SAT Competition 的官方证明集（多为 kissat / cadical 的大实例）没有整包对比。
- 检查器 k=10（295345 行）校验 127s，仍比 `drat-trim` 慢约 7 倍，瓶颈在传播调度。
- 最大实例 400 变量（20×20 网格；鸽巢 k=10 是 90 变量、295345 行证明），未与工业求解器同数据集比较。

这些边界在 `docs/roadmap.md` 与申报书的「范围边界」里都写着，没有包装成已完成。
