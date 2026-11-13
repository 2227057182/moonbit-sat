# 贡献指南

## 环境

- MoonBit 工具链（`moon` 0.1.2026xxxx 及以上）
- 标准库 `moonbitlang/core` 已通过 `moon bundle` 为所需后端准备好
- 不需要任何外部依赖

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
- 任何修复真实缺陷的提交，在 `docs/design.md` 的对应小节留下该缺陷的说明，避免下次重犯。

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

- 证明只产出 RUP 步骤，校验器不接受 RAT。
- MaxSAT 总软权重受 `weight_cap` 限制，超限直接报错而不是截断。
- 不支持文件 IO（MoonBit core 没有文件系统模块），命令行用内联文本参数。
- 不引入外部 SAT 求解器依赖。
