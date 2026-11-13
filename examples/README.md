# 示例实例

这里的文件是标准 DIMACS CNF / WCNF 文本，可以用任何 SAT 工具读取。本项目的命令行不接受文件 IO（MoonBit core 没有文件系统模块），所以运行前要把文件内容压成一行、用 `;` 代替换行。

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
