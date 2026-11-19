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

- [ ] 完整 OLL/WPM1 core-guided MaxSAT：需要稳定的松弛变量体系与权重拆解（每轮扣掉 core 的最小权重、把 core 的析取作为新软子句回收），当前只做了 core 提取与下界

## 计划中

- [ ] 校验器进一步提速：k=10 级鸽巢证明（295345 行、90 变量）仍需约 350s，瓶颈是每个文字挂着的监听条数，需要更强的 RUP 复算调度而非继续改监听结构
- [ ] 预处理：纯文字消除、变量消除、子句自吸收
- [ ] MaxSAT 的线性搜索编码（totalizer），放宽 `weight_cap` 限制
- [ ] Mooncakes 发布（需维护者在本机执行 `moon login && moon publish`）
- [ ] 大实例压力测试（百万变量级内存与耗时）

## 不做

- 并行求解。四后端一致性优先，多线程会引入后端差异，超出本期范围。
- 图形界面或产品化封装。本项目定位是库与命令行，不是应用。
- 依赖外部 SAT 求解器。零外部依赖是设计前提，用来验证实现本身的正确性。
