# 示例实例

这里的文件是标准 DIMACS CNF / WCNF 文本，可以用任何 SAT 工具读取。0.7.6 起命令行支持 `@路径`（读盘由官方 `moonbitlang/x/fs` 完成），所以这些文件可以直接当参数；下面的命令同时给出内联写法，两者等价。

```bash
moon run cmd/main -- solve @examples/simple-sat.cnf
moon run cmd/main -- verify @examples/pigeonhole-3-2.cnf @p32.drat
```

## 可满足实例 `simple-sat.cnf`

```
p cnf 3 2;1 2 0;-1 3 0
```

```
moon run cmd/main -- solve "p cnf 3 2;1 2 0;-1 3 0"
```

预期：`s SATISFIABLE`，输出模型与 `c decisions=...` 统计行。

## 不可满足实例 `pigeonhole-3-2.cnf`

3 只鸽子放进 2 个洞，鸽巢原理保证无解。

```
moon run cmd/main -- proof "p cnf 6 9;1 2 0;3 4 0;5 6 0;-1 -3 0;-1 -5 0;-3 -5 0;-2 -4 0;-2 -6 0;-4 -6 0"
```

预期：`s UNSATISFIABLE`，随后是 DRAT 证明。把打印出的证明文本交给 `verify` 子命令，应得到 `s VERIFIED`。

## 加权实例 `scheduling.wcnf`

两个任务、两个槽位，硬约束要求各占一槽且不冲突，软约束表达偏好。

```
moon run cmd/main -- maxsat "p wcnf 4 7 10;10 1 2 0;10 3 4 0;10 -1 -3 0;10 -2 -4 0;3 1 0;1 -1 0;2 4 0"
```

预期：`o 1` 与 `s OPTIMUM FOUND`——两条关于 task1 的软偏好互相冲突，最低代价为 1。

## 最小顶点覆盖实例 `petersen-mwvc.wcnf` 与 `grid-mwvc.wcnf`

顶点覆盖是 partial MaxSAT 的经典应用：每条边一条硬子句 `(u v)`（至少选一个端点），每个顶点一条软子句 `(-v)` 权重 1（选它就要付 1）。求解代价就是最小顶点覆盖的大小。

把文件去注释、用 `;` 连成一行即可运行：

```
moon run cmd/main -- maxsat "<p wcnf ...;2 1 2 0;...>"
```

预期：`petersen-mwvc.wcnf` 输出 `o 6`，`grid-mwvc.wcnf` 输出 `o 10`——两个值都有独立的已知依据（下界论证与 König 定理），见 `docs/benchmarks.md`。

