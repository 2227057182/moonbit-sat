# 贡献指南

## 环境

- MoonBit 工具链（`moon` 0.1.2026xxxx 及以上）
- 标准库 `moonbitlang/core` 已通过 `moon bundle` 为所需后端准备好
- 库本身不需要外部依赖；命令行可执行包会自动拉取官方 `moonbitlang/x`（`moon build` 时联网一次，之后走缓存）

## 构建与测试

```bash
moon check --deny-warn
moon test
moon test --target js
```

四个后端都要能构建：

```bash
moon build --target wasm
moon build --target wasm-gc
moon build --target js
moon build --target native
```

`--deny-warn` 是硬要求：任何告警都视为失败。新增代码不允许留下未使用变量、未使用 `mut`、废弃语法。

## 代码约定

- 注释说明**为什么**，不重复代码已经说清的内容。
- 热点路径（传播、分析、堆操作）不分配不必要的中等对象；必须有分配时在注释里说明原因。
- 新增公开接口时同步更新 `docs/api.md`；改变算法行为时同步更新 `docs/design.md`。
- 任何修复真实缺陷的提交，在 `docs/fixes.md` 追加一条：症状、怎么发现的、修法、以及现在靠什么防复发（没有防复发措施的条目，等于还没修）。

## 测试要求

- 求解器改动必须能被「暴力真值表」对拍覆盖（变量数 ≤ 12 时可用 `brute_sat` 风格参照）。
- 证明相关改动必须同时验证两种情况：合法证明返回 `true`，伪证明返回 `false`。只测前者等于没测。
- MaxSAT 改动必须与暴力枚举的最优成本比对。
- 新测试放在独立的 `*_wbtest.mbt` 文件中，不要挤进主测试文件。

## 提交规范

提交信息用 `type(scope): summary` 形式，`type` 取 `feat` / `fix` / `test` / `docs` / `chore`。

一次提交只做一件事：加功能、补测试、写文档分开提交。这样做不是为了好看，而是让审阅者能单独回退某一类改动。

## 边界声明

以下限制是有意为之，改动它们需要先在 Issue 中讨论：

- 求解器只产出 RUP 证明步骤；检查器默认 `verify_proof` 严格 RUP，另有 `verify_proof_rat` / `verify-rat` 接受 RAT（外部求解器的证明常含 RAT 引理）。
- 编码路径的总软权重受 `weight_cap` 限制，超限直接报错而不是截断；核心引导（`maxsat_oll`）没有总权重上限。
- 库不做文件 IO（`parse_dimacs` / `parse_wcnf` 只吃文本）；命令行可以内联文本，也可以用 `@路径` 读文件（0.7.6 起，走官方 `moonbitlang/x/fs`）。
- 不引入外部 SAT 求解器依赖。
