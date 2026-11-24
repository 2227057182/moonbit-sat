# 本期（十一月）新增了什么

对应验收条「工作有效：本期有实质新增」。这里只列十一月一日起进仓库的东西，按能力而非按提交排列；每条都给出可核对的位置。

## 从 0.5.0 到 0.7.16

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
| 核心引导可设轮预算 | 0.7.0 | 不收敛的实例只能干等，没有任何出口 | `maxsat_oll_result(w, rounds)` 返回 `Solved` / `Infeasible` / `Budgeted(下界, 上界)`；20×20 加权网格给 20 轮在不到 10ms 就返回 `lower= 2000 upper= 40000`；另有一个三条三元超边的加权超图实例与编码路径对拍（`o 200`），覆盖不是顶点覆盖的形态 | `maxsat.mbt`、`maxsat_oll_wbtest.mbt`、`cmd/main/main.mbt`、`docs/usage.md` |
| 读入外部求解器的证明 | 0.7.1 | 检查器只被自己的求解器喂过证明，`verify-rat` 的读入路径没有真实样本 | CaDiCaL 3.1.0 的鸽巢 6/5（235 行、156 添加 79 删除）与 7/6（1846 行）证明原样通过 `verify` 与 `verify-rat`，`drat-trim` 结论一致；删掉末尾空子句即被拒绝。两份证明已内联成测试，复跑不需装 CaDiCaL | `external_proof_wbtest.mbt`、`docs/crosscheck.md`「反方向」 |
| 输入面加固 | 0.7.4 | 负权重 WCNF 让 `maxsat` 直接 abort；缺 header 的实例把所有软子句当硬子句；非数字参数读成 0；`bench-verify 11` 静默测 k=8 | 新增 `wcnf_error`，9 处 CLI 解析后检查、5 处整数参数检查，全部改成一行 `c error:` 并以 0 退出；库层面负权重 `raise`、负 k 返回空子句；5 个新测试（82 → 87） | `maxsat.mbt`、`cmd/main/main.mbt`、`wcnf_guard_wbtest.mbt`、`docs/usage.md` |
| 外部复核最优性 | 0.7.7 | `maxsat-verify` 只能验自己算出的那一对 `o` 与证明，第三方没有复核入口 | `maxsat-verify-external` 接受外部赋值与外部证明，`opt-1` 的 DRAT 在重建编码上重放；CaDiCaL 3.1.0 实测 Petersen 5–10 ms、10×10 网格 62 ms，两份证明 `drat-trim` 也 VERIFIED；3 个测试（90 → 93） | `maxsat.mbt`、`cmd/main/main.mbt`、`maxsat_external_wbtest.mbt` |
| 命令行读文件 | 0.7.6 | 公式与证明只能内联，单个参数 128 KB 上限，24 MB 的 k=10 证明没法通过命令行校验 | 以 `@` 开头的参数按路径读盘，`verify @cnf @drat` 直接可用；native 上 k=10 的 24.7 MB 证明整条命令 89 s 得 `s VERIFIED`（含读盘与解析）；读不到时 `c error: cannot read file <path>`；内联调用完全不变 | `cmd/main/main.mbt`、`cmd/main/moon.pkg`、`docs/usage.md` |
| 证明越界不再崩溃 | 0.7.6 | 证明引用公式未声明的变量（`999 0` 配两变量公式）会索引越界 abort | `steps_in_range` 前置扫描，越界判 `s PROOF-REJECTED`；24 MB 证明多 0.6% 时间；3 个新测试（87 → 90） | `checker.mbt`、`checker_guard_wbtest.mbt` |
| 子句池回收 | 0.7.8 | 归约删掉的子句只标 `dead`，文字数组仍被引用，随冲突数线性累积（php-10 上死子句占 62%、死文字 315 万） | 标记的同时清空并释放文字数组，结果逐位不变，php-10 峰值 RSS 112.4 → 92.3 MB（-18%），时间无可归因变化；2 个新测试（93 → 95） | `solver.mbt`、`clause_pool_wbtest.mbt`、`docs/design.md`、`docs/benchmarks.md` |
| 裁剪式复算的评估 | 0.7.5 | roadmap 记着「k=10 时 drat-trim 只验 172527 条」，把它当成与本检查器 4–7 倍差距的主要来源 | 用临时 reason 探针实测核心闭包：k=9 是 93%、k=10 是 87%，只有 k=8 能裁掉 65%；带探针开销 6%，真正贵的两档省不到 10 s，跳过验证还要在时序约束下还原池，判定不做 | `docs/proof.md`、`docs/roadmap.md` |
| 结论层的外部对拍 | 0.7.10 | 求解器的 SAT/UNSAT 结论只有内部测试覆盖，外部只验过证明 | `tools/difftest.sh` 拿 CaDiCaL 3.1.0 当独立结论源：1400 个随机 3-SAT 全部一致，736 个 SAT 模型由不依赖本库的 `check_model.py` 逐子句复核，664 个 UNSAT 证明全部交 `drat-trim`（0.7.12 起从抽样改成全验，约 50 秒） | `tools/`、`docs/crosscheck.md`「结论对拍」 |
| 十分钟审计与缺陷清单 | 0.7.11 | 评审要在十几篇文档里自己拼证据；真实缺陷散落在 `design.md` 各节 | `docs/audit.md` 把六条验收拆成可执行命令（附预期输出与「不符意味着什么」），`docs/fixes.md` 逐条记真实缺陷的症状、发现、修法与防复发（0.7.11 时 9 条，0.7.16 补到 10 条） | `docs/audit.md`、`docs/fixes.md` |
| 加权最优值的外部裁判 | 0.7.12 | `o` 这个数只有内部一致性：结论对拍只比 SAT/UNSAT，`maxsat-verify` 验的也是自家上下界彼此一致 | `tools/maxsat_bruteforce.py` 枚举全部 2^n 个赋值求真最优：400 个随机 WCNF（8–16 变量）全部相等，0 不等、0 求解失败，整轮 9.4 秒 | `tools/maxsat_bruteforce.py`、`docs/crosscheck.md`「加权最优值」 |
| 文档口径自查（第二轮） | 0.7.14 | 上一轮复核之后又有新的落伍表述：`examples/README.md` 说「命令行不接受文件 IO」、`proof.md` 的「已知缺口」说没有外部验最优性的入口、`usage.md` 给 `solve` 多写了 `-1 0`、仓库内申报书副本停在 0.7.9 | 逐篇对照源码修正 14 处（明细见 `CHANGELOG.md` 的 0.7.14 段）；`docs/申报书.md` 的版本号改为以 `moon.mod` 为准，不再写死 | `CHANGELOG.md`、`docs/fixes.md` |
| 文档口径自查可执行 | 0.7.16 | 文档与源码对不上只能靠人逐页读：0.7.14 一轮读出 14 处，0.7.15 又读出 2 处，两轮都是人眼扫出来的 | `tools/doccheck.sh` 把六类判定做成命令（子命令名、当前版本、版本区间、测试数、`docs/` 篇数、`.mbt` 数、`extern` 计数），期望值现读不写死；`tools/doccheck_selftest.sh` 故意改坏三处确认能抓（3/3）；`.githooks/pre-commit` 拦住口径不符的提交；`tools/audit.sh` 把 `docs/audit.md` 六组命令变成 `PASS`/`FAIL`/`SKIP` | `tools/`、`docs/audit.md`、`CONTRIBUTING.md` |

## 量化

- 测试：37 → 95；native / js / wasm / wasm-gc 四个后端各跑一遍都是 95/95、结论相同（`moon build --release` 四后端全过），`moon check --deny-warn` 零告警。
- 命令：8 → 18 个子命令（新增 `grid-wcnf`、`maxsat-cnf`、`maxsat-proof`、`verify-maxsat`、`maxsat-verify`、`maxsat-solution`、`maxsat-oll`、`maxsat-oll-budget`、`verify-solution`、`maxsat-verify-external`）。
- 文档：`docs/` 共 13 篇（新增 `benchmarks.md`、`proof.md`、`november.md`、`reproduce.md`、`crosscheck.md`、`audit.md`、`fixes.md`、`申报书.md`）。
- 提交：十一月一日起的每次提交都在历史里可数（`git log --since=2026-11-01 --oneline | wc -l`，0.6.7 发布前 78 次），包含一次已合并的外部 PR 与一个关闭的 Issue（#6，记录 MaxSAT 最优性证明这项工作）。
- 发布：Mooncakes 0.5.0 起持续发布，当前最新版本见 `moon.mod`，每次 `build=success`；0.6.4 起每个版本都有 tag 与 GitHub Release。

## 没有做到的

- 核心引导的 at-least 基数网络没有实现：三组实例实测下界每轮只涨 `wmin`，at-least-k 的 k 恒为 1，形式上的补齐不改变任何数字（推导见 `docs/proof.md`，这是主动放弃而非遗漏）。
- 核心引导路径在均匀权重的大图上按层推进，每轮一层：20×20 加权网格仍没有跑到收敛，只能靠轮预算带界返回（`lower= 2000 upper= 40000`）；大均匀权重实例仍应走编码路径。
- 外部证明只覆盖一个求解器、两个小实例：CaDiCaL 3.1.0 对鸽巢 6/5 与 7/6 写出的都是纯 DRUP，`verify-rat` 的 RAT 分支没有真实外部样本；SAT Competition 的官方证明集（多为 kissat / cadical 的大实例）没有整包对比。
- 检查器 k=10（295345 行）校验 127s，仍比 `drat-trim` 慢约 7 倍，瓶颈在传播调度。
- 最大实例 400 变量（20×20 网格；鸽巢 k=10 是 90 变量、295345 行证明），未与工业求解器同数据集比较。

这些边界在 `docs/roadmap.md` 与申报书的「范围边界」里都写着，没有包装成已完成。
