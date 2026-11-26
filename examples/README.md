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


## 真实场景：数独（`examples/sudoku/`）

前面几个实例是「为了展示能力而构造的」。这一节反过来：拿一个真实问题，走一遍完整链路。目录里是一个独立的可执行包，它只依赖本库，不发一行 FFI、不碰求解器内部。

编码：729 个变量 `v(r,c,d)` 表示「第 r 行第 c 列填 d+1」，四类约束共 11745 条（每格至少一个数字 81 条、格内互斥 2916 条、每行/每列/每宫各数字一次 8748 条），提示格写成单元子句。

```
moon run examples/sudoku --                        # 默认题：AI Escargot
moon run examples/sudoku -- 15...7.9.3..2...8...   # 或自己给 81 个字符，. 表示空
```

默认题实测（native release）：

```
c vars=729 clauses=11768
s SATISFIABLE
+-------+-------+-------+
| 1 6 2  8 5 7  4 9 3 |
...
c decisions=349 propagations=16492 conflicts=243 restarts=2 learnts=243 minimised=354
c verified=true
```

9 毫秒解完，`c verified=true` 来自一段不读求解器任何内部状态的复核：每格 1–9、27 组（9 行 + 9 列 + 9 宫）里每个数字恰好一次、与提示一致。

把其中一格提示改错（第 2 格填 5，正确答案是 6），同一套编码变成 UNSAT，同时得到一份可独立复算的证明：

```
c vars=729 clauses=11769
s UNSATISFIABLE
c decisions=159 propagations=10458 conflicts=131 restarts=1 learnts=130 minimised=104
c proof lines=132
c proof self-check=true
```

`s proof self-check=true` 是 `verify_proof` 把这份 132 行 DRAT 逐条 RUP 重放的结果。也就是说，同一个示例里既有「求解真实问题」，也有「结论可被独立检查」这两件事，都不用额外工具。

这个包自带 4 个回归测试（编码规模、Escargot 可解且复核通过、改一格后 UNSAT 且证明被接受、短输入被拒绝），跟库的其余测试一起在 `moon test` 里跑。
