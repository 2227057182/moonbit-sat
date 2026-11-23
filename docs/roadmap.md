# 路线图

本文件记录已完成与计划中的工作。计划项在 GitHub Issues 中有对应条目，完成情况以本文件与 Issues 为准。

## 已完成

- [x] 字面编码、CNF 数据结构、DIMACS 解析与输出
- [x] 双监听字面单位传播
- [x] 1-UIP 冲突分析、断定为文字置于 index 0、回跳层计算
- [x] VSIDS 变量活跃度 + 二叉堆分支
- [x] 相位保存
- [x] Luby 序列重启（间隔 `100 * luby(restarts)`，序列 1, 1, 2, 1, 1, 2, 4, …）
- [x] 基于 LBD 与活跃度的学习子句归约
- [x] 增量 `add_clause` 与临时假设求解
- [x] DRAT 风格证明记录（学习、删除、终结空子句）
- [x] 独立 RUP 校验器（不共享求解器实现）
- [x] WCNF 解析、Sinz 顺序计数器编码、二分最优化
- [x] 四后端构建（wasm / wasm-gc / js / native）
- [x] 单元测试与随机对拍（含暴力真值表、暴力 MaxSAT）
- [x] 命令行入口（solve / proof / verify / maxsat）
- [x] 子句去重与重言子句消除（`Formula::simplify`）
- [x] 冲突预算（`solve_with_budget` 返回 `Unknown`，中断后可继续求解）
- [x] 学习子句最小化（递归 minimization，`minimised` 统计删除的字面数）
- [x] 基准命令 `bench`（固定随机 3-SAT 阶梯，输出搜索量）
- [x] RAT 校验（`check_drat_rat` / `verify_proof_rat`，接受引入新变量的定义步骤）
- [x] 检查器两文字监听增量传播（替换逐条全池扫描，k=9 证明校验提速 5.5 倍）
- [x] 基准命令 `bench-verify`（进程内构造鸽巢实例、求解、校验并打印证明行数，绕开命令行参数上限）
- [x] UNSAT core 提取（`solve_core`，沿最终冲突的 reason 图回溯）与 MaxSAT 的 core 下界（`maxsat_core_bound`，用于收紧二分区下端点）
- [x] MaxSAT 最优性可复算：`maxsat_encoding` 显式构造「代价 ≤ k」的 CNF，`maxsat_bound_proof` 导出 `k` 不可达的 DRAT 证明，`verify_maxsat_bound` 重建同一编码后复算；命令行 `maxsat-proof` / `verify-maxsat` / `maxsat-verify`
- [x] MaxSAT 上界可达：`maxsat_solution` 取回达到最优值的赋值，`maxsat_model_cost` 按 WCNF 原文复算代价，`verify_maxsat_solution` 核对声称值；命令行 `maxsat-solution` / `verify-solution`，`maxsat-verify` 升级为「上界 + 下界」双端校验
- [x] Mooncakes 发布（0.6.1、0.6.2、0.6.3）

## 计划中

- [x] 核心引导加权 MaxSAT（0.6.8）：每轮取 core、扣掉 `wmin` 记账、饱和该层并把剩余权重交给新松弛文字；下界只增，同时用模型违反的软子句作阻塞子句收紧上界。不建基数编码，因此没有总权重上限
- [x] 核心引导的轮数预算（0.7.0）：`maxsat_oll_result` 用尽预算时返回 `Budgeted(下界, 上界)`，不收敛的实例也有出口
- [x] 核心引导的 at-least 基数网络：已评估，不实现。at-least-k 的 k 上界是 `min_i(w_i)/wmin`，而 `wmin` 就是组内最小值，商恒为 1，每一轮都会退化成一条 at-least-1 子句；三组实例实测每轮只涨 `wmin`。数据和推导见 `docs/proof.md`「为什么没有 at-least 基数网络」
- [x] 最优性证明接外部工具链（drat-trim 等）：0.6.5 起 `maxsat-cnf` 落地编码后的 CNF、`maxsat-proof` 导出证明，可交给 `drat-trim` 与 `lrat-check`
- [x] 读入别的求解器产出的证明（0.7.1）：CaDiCaL 3.1.0 的鸽巢 6/5 与 7/6 证明原样内联进测试，`verify` 与 `verify-rat` 都通过，删掉空子句即被拒绝；RAT 分支仍只有单元测试支撑
- [ ] 校验器进一步提速：k=10 级鸽巢证明（295345 行、90 变量）仍需约 350s，瓶颈是每个文字挂着的监听条数，需要更强的 RUP 复算调度而非继续改监听结构
- [ ] 预处理：纯文字消除、变量消除、子句自吸收
- [ ] MaxSAT 的线性搜索编码（totalizer），放宽 `weight_cap` 限制
- [ ] 大实例压力测试（百万变量级内存与耗时）

## 不做

- 并行求解。四后端一致性优先，多线程会引入后端差异，超出本期范围。
- 图形界面或产品化封装。本项目定位是库与命令行，不是应用。
- 依赖外部 SAT 求解器。零外部依赖是设计前提，用来验证实现本身的正确性。
- 为了「完整性」写一个不会走到的 at-least 计费分支。见 docs/proof.md，实测它不改变任何一个数字。
