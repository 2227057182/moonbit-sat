# 变更记录

版本号遵循 `moon.mod` 中的 `version` 字段。

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
