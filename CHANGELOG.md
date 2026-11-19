# 变更记录

版本号遵循 `moon.mod` 中的 `version` 字段。

## 0.6.0

### 新增

- `Solver::solve_core(assumptions) -> (Bool, Array[Lit])`：判定 UNSAT 时额外返回假设的一个子集，该子集**本身不可满足**。提取方式是沿最终冲突的 reason 图回溯（`analyze_final`），只收集为假设建立的决策层；不保证最小，但保证单独拿这个子集去求解仍然 UNSAT。硬子句本身不可满足时返回空 core。
- `maxsat_core_bound(w)`：用一个 unsat core 给出最优代价的下界——core 内的软子句不能同时成立，最便宜的那条必然被违反。硬子句不可满足返回 `-1`，软子句可全部满足返回 `0`。
- `maxsat_solve` 的二分区下端点改为从该下界起步，省掉一部分注定失败的判定。
- 命令行 `core <dimacs> <lits>`：打印给定假设的 unsat core；空 core 表示与假设无关、硬子句本身已不可满足。

### 验证

- `moon check --deny-warn` 无告警；47 个测试在 wasm 与 js 后端通过。
- core 合法性不是靠断言长度判断的：每个报告出来的 core 都被单独作为假设重新求解，必须仍然 UNSAT；另有测试确认无关假设不会混进 core。
- 下界与暴力枚举出的最优值对拍（含 `maxsat_solve` 的既有随机对拍），未出现下界高于最优的越界。

### 边界

- 这不是完整的 OLL/WPM1 core-guided 求解器。完整实现需要稳定的松弛变量体系与权重拆解（每轮把 core 的最小权重扣掉、并把 core 的析取作为新软子句回收），这些基础设施本版本没有建。当前只做了 core-guided 的最小可用部分：core 提取 + 下界收紧。

## 0.5.0

### 新增

- 命令行 `bench-verify <k>`：进程内构造 `k` 鸽 `k-1` 洞实例、求解、取证明文本、统计行数并校验。操作系统对单个命令行参数有上限（Linux 为 128KB），`k >= 8` 的证明根本传不进去，这个子命令绕开该限制，同时给出可复现的校验耗时基线。

### 变更

- 检查器由「每条 RUP 全量扫描子句池」改为两文字监听（watcher）增量传播：`CheckDb` 持有子句池、`alive` 标记、每个文字的监听列表、赋值数组与 trail；`propagate` 只处理被置假文字对应的监听列表，命中子句就地转移监听点或触发单位赋值。
- 单元子句构成 trail 的基座层，`reset` 只回滚假设层之上的赋值，单元事实不再每次重播。
- 删除步骤走开放式子句哈希（8192 桶）定位，不再线性扫描整个池。
- 传播时监听列表就地压缩，省掉每轮一次数组分配。
- 证明中出现超出 `num_vars` 的变量时自动扩容，不再按声明范围判定。

### 验证

- `moon check --deny-warn` 无告警；37 个测试在 wasm 与 js 后端通过。
- 同一批证明（行数逐字不变）在 native release 下重新计时：`k=7` 0.04s → 0.02s、`k=8` 0.66s → 0.16s、`k=9` 32.56s → 5.96s，k=9 提速 5.5 倍且仍判 `VERIFIED`。
- k=10（295345 行、90 变量）约 350s：鸽巢证明的子句数远多于变量数，平均每个文字挂着数千条监听，传播成本是结构性的，已记入 roadmap。

## 0.4.0

### 新增

- RAT 校验：`check_drat_rat` / `verify_proof_rat` 在 RUP 失败后按 pivot 求归结，归结式仍需为 RUP；池中没有含否定 pivot 的子句时直接成立，因此能接受引入新变量的定义步骤。`check_drat` / `verify_proof` 保持严格 RUP 语义不变。
- 命令行 `verify-rat` 子命令，走完整 RUP + RAT 规则；`verify` 仍是严格模式。

### 验证

- `moon check --deny-warn` 无告警；37 个测试通过（新增 4 个 RAT 测试，含「RUP 拒绝而 RAT 接受」与「两种模式都拒绝」两类）。
- 求解器自身产出的证明在 strict 与 full 两种模式下结论一致，确认 RAT 没有放松对自家证明的判定。

## 0.3.0

### 新增

- 递归学习子句最小化：断定为文字之外，reason 链完全被子句或 0 层覆盖的字面会被删除；`minimised` 统计累计删除量并出现在 `stats_string`。
- 命令行 `bench` 子命令：在固定的随机 3-SAT 阶梯上输出决策、传播、冲突与最小化删除量，实例由写死种子的线性同余发生器生成，可复现。

### 验证

- `moon check --deny-warn` 无告警；33 个测试通过（新增 3 个最小化测试）。
- 最小化后的证明在 5 鸽 4 洞实例上仍被独立检查器判定为 `VERIFIED`。

## 0.2.0

### 新增

- `Solver::solve_with_budget` 与 `SolveOutcome`（`Satisfiable` / `Unsatisfiable` / `Unknown`）：限制冲突数，超预算即回退到 0 层并保留学习子句，可继续求解。
- `docs/usage.md`：安装、库调用、命令行输出格式与常见问题。
- `docs/origin.md`：算法出处、依赖情况、许可证与证明校验独立性说明。

### 变更

- 重启策略由线性增长改为 Luby 序列，间隔为 `100 * luby(restarts)`。
- README 补充冲突预算说明与两份新文档的入口。

### 验证

- `moon check --deny-warn` 无告警；30 个测试在 wasm 与 js 后端通过。

## 0.1.1

### 新增

- `Formula::simplify`：子句内重复文字去重、重言子句（同时含 `l` 与 `¬l`）消除，返回删除条数。
- `Formula::num_tautologies`：只读统计重言子句数量，便于提示冗余输入。
- `edge_wbtest.mbt`：11 个边界测试，覆盖空公式、空子句、重复文字、重言子句、变量越界、证明删除行、连续假设调用、MaxSAT 硬冲突与无软子句实例。
- `docs/design.md`：算法与数据结构设计说明，含关键不变量与真实缺陷的修复记录。
- `docs/api.md`：公开接口逐项说明。
- `docs/roadmap.md`：已完成与计划项清单。
- `examples/`：DIMACS 与 WCNF 样例实例及运行说明。
- `.github/ISSUE_TEMPLATE/`：缺陷与需求模板。

### 修复

- `parse_dimacs` 忽略独占一行的 `0`，导致空子句被静默丢弃、本应 UNSAT 的输入被判为 SAT。现在 `0` 按 DIMACS 严格语义产生空子句。

### 验证

- `moon check --deny-warn` 无告警。
- 24 个测试在 wasm 与 js 后端全部通过。

## 0.1.0

首个可运行版本。

- CDCL 求解器：双监听传播、1-UIP 分析、VSIDS、相位保存、线性重启、LBD 归约。
- DRAT 风格证明记录与独立 RUP 校验器。
- WCNF 解析、Sinz 基数编码、二分最优化。
- 四后端构建（wasm / wasm-gc / js / native）。
- 命令行入口（solve / proof / verify / maxsat）。
