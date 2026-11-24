# 外部交叉验证

自己生成的证明，用自己的检查器验，只能证明「两边一致地理解同一件事」。如果对 DRAT 的某个约定理解错了，生成和检查会一起错，而且看起来完全自洽。所以这一页把同一批证明交给两个与本项目没有共享代码的 C 检查器复算。

## 工具

| 工具 | 来源 | 在这里的角色 |
| --- | --- | --- |
| `drat-trim` | `marijnheule/drat-trim`（SAT Competition 使用的检查器） | 独立解析 DIMACS + DRAT，backward 与 `-f` forward 两种模式各算一遍 |
| `lrat-check` | 同一仓库的 `lrat-check.c`，独立实现 | 检查由 `drat-trim -L` 导出的 LRAT：带提示的证明，逐条核对 resolvent |

两者都是单文件 C 程序，`tools/crosscheck.sh` 自动下载并用 `gcc -O2` 编译到 `_build/crosscheck/`。仓库里不放第三方源码，只放下载地址，第三方代码始终是它们上游的版本。

## 怎么跑

```bash
moon build --target native --release
bash tools/crosscheck.sh
```

脚本自带鸽巢实例生成器，不依赖 `examples/` 里的静态文件；`M=/别处的/main.exe bash tools/crosscheck.sh` 可以对任何一份 CLI 复算。全部通过时最后一行是 `all cases verified by drat-trim and lrat-check`，任一案例失败则退出码非 0。

## 结果

Linux 云主机、native release、`gcc 11.4`、单次运行：

| 案例 | 证明行数 | drat-trim | lrat-check | drat-trim | lrat-check |
| --- | --- | --- | --- | --- | --- |
| 鸽巢 3 鸽 2 洞 | 2 | `s VERIFIED` | `c VERIFIED` | 68 ms | 27 ms |
| 鸽巢 4 鸽 3 洞 | 7 | `s VERIFIED` | `c VERIFIED` | 70 ms | 26 ms |
| 鸽巢 5 鸽 4 洞 | 29 | `s VERIFIED` | `c VERIFIED` | 77 ms | 30 ms |
| 鸽巢 6 鸽 5 洞 | 145 | `s VERIFIED` | `c VERIFIED` | 72 ms | 26 ms |
| 鸽巢 7 鸽 6 洞 | 670 | `s VERIFIED` | `c VERIFIED` | 77 ms | 29 ms |
| 鸽巢 8 鸽 7 洞 | 3942 | `s VERIFIED` | `c VERIFIED` | 115 ms | 34 ms |
| 鸽巢 9 鸽 8 洞 | 40273 | `s VERIFIED` | `c VERIFIED` | 768 ms | 105 ms |
| Petersen 最小点覆盖，代价 ≤5 不可达 | 13 | `s VERIFIED` | `c VERIFIED` | 69 ms | 25 ms |
| 10×10 网格最小点覆盖，代价 ≤9 不可达 | 16 | `s VERIFIED` | `c VERIFIED` | 70 ms | 26 ms |
| 排班，代价 ≤0 不可达 | 1 | `s VERIFIED` | `c VERIFIED` | 74 ms | 26 ms |

`drat-trim` 的分项统计也一起记下来，因为它说明证明的形状：

| 案例 | core 里的引理 | resolution 步数 | RAT 引理 | 冗余文字 |
| --- | --- | --- | --- | --- |
| 鸽巢 7 鸽 6 洞 | 627 / 671 | 7580 | 0 | 95 |
| 鸽巢 9 鸽 8 洞 | 25634 / 27103 | 376770 | 0 | 14076 |
| Petersen，代价 ≤5 | 12 / 14 | 140 | 0 | 0 |

### 更大的实例

| 案例 | 规模 | 证明行数 | drat-trim | lrat-check |
| --- | --- | --- | --- | --- |
| 鸽巢 10 鸽 9 洞 | 90 变量 / 371 子句 | 295345 | `s VERIFIED` | `c VERIFIED`（30 MB LRAT） |
| 20×20 网格最小点覆盖，代价 ≤199 不可达 | 编码后 80201 变量 / 159964 子句 | 8622 | `s VERIFIED` | 未跑 |

两行的耗时分别是约 17 s 与约 0.5 s。k=10 那行最能说明外部工具的价值：本项目自己的检查器要 350 秒（0.6.7 摊平子句池后降到 127 秒，仍约 7 倍），`drat-trim` 约 17 秒、`lrat-check` 约 0.7 秒，但三家结论完全一致。20×20 那行的证明只有 8622 行，`drat-trim` 253 毫秒就验完了——慢的从来不是证明，是我们自己的检查器。

这两行不放在默认脚本里（k=10 要先跑 223 秒求解），用 `BIG=1 bash tools/crosscheck.sh` 单独触发。

两点值得单独说明。

**全部案例都是 0 RAT 引理。** 也就是说本项目输出的证明是纯 RUP（DRUP）：每条学到的子句都能靠单元传播从已有子句推出冲突，不需要 RAT 的「对该文字所有子句做 resolvent」那套机制。这让外部检查的门槛降到最低——任何只支持 DRUP 的检查器也能用。项目里的 `verify-rat` 是为读别人的证明准备的，不是为自己输出准备的；下一节给出真实的读入样本。

**加权部分现在也能交给外部检查器。** 以前 `maxsat_bound_proof` 只能用自己的检查器复验，因为编码后的 CNF 没有导出入口，外人拿不到「公式」。0.6.5 起 `maxsat-cnf <wcnf> <k>` 直接打印 `maxsat_encoding(w, k)` 的 DIMACS，于是「最优性下界」也能走 `drat-trim` + `lrat-check`：拿到的公式和证明都来自本项目，判定则由第三方给出。

```bash
# 公式与证明分开取，交给任意 DRAT 检查器
M=_build/native/release/build/cmd/main/main.exe
$M maxsat-cnf "$(cat examples/petersen-mwvc.wcnf)" 5 > enc.cnf
$M maxsat-proof "$(cat examples/petersen-mwvc.wcnf)" 5 | grep -E '^(-?[0-9]|d )' > bound.drat
drat-trim enc.cnf bound.drat
```

`maxsat-cnf 5` 的语义是「软代价 ≤ 5 是否可行」，`petersen` 的最优代价是 6，所以这个公式不可满足，它的证明才构成最优性下界的证据。取 `k = opt` 时公式可满足，`maxsat-proof` 会返回 `s SATISFIABLE (cost <= opt achievable)` 而不是证明——这一点也是可验证的。

## 反方向：别人产的证明，我们验

上面全是「本项目产证明、第三方判定」。反方向同样重要：如果检查器只认自己求解器写出的形状，它就只是个自洽的回声。0.7.1 起仓库里带着一份真正外来的证明。

用 CaDiCaL 3.1.0（`git clone` 后 `./configure && make`，`gcc 11.4`）对鸽巢 6 鸽 5 洞求解，写 ASCII DRAT：

```bash
cadical --binary=false php-6.cnf php-6.drat
# s UNSATISFIABLE；证明 235 行：156 条添加、79 条删除，末尾是空子句
```

同一份证明交给三家：

`--binary=false` 不是可选项：本项目的 `verify` 与 `verify-rat` 只解析 ASCII DRAT，CaDiCaL 默认写二进制；二进制文件会被读成杂乱的小子句集并判 `PROOF-REJECTED`，而不是报格式错误。

| 检查器 | 结果 |
| --- | --- |
| 本项目 `verify`（只认 RUP） | `s VERIFIED` |
| 本项目 `verify-rat`（RUP + RAT） | `s VERIFIED` |
| `drat-trim` | `s VERIFIED`，0 RAT 引理 |

鸽巢 7 鸽 6 洞同样过：CaDiCaL 写出 1846 行 / 37 KB，本项目两个检查器都判 `s VERIFIED`。

验收是有条件的：删掉末尾那个空子句，同一份文件立刻变成 `s PROOF-REJECTED`（`verify` 与 `verify-rat` 一致）——不是把文件读进来就点头。

公式（82 行）与证明（235 行）已经内联进 `external_proof_wbtest.mbt` 的两个测试，`moon test` 直接复跑，不必装 CaDiCaL，也不依赖网络。

**它没有覆盖的**：CaDiCaL 3.1.0 在这两个实例上写出的都是纯 DRUP，没有一行需要 RAT。试过 `--block`、`--elimfast`、`--sweep` 与含 ITE 门、XOR 门的构造实例，它仍然只产 RUP 行，所以 `verify-rat` 的 RAT 分支目前只有 `rat_wbtest.mbt` 里的正例与反例支撑，没有真实外部样本。


## 反方向的另一半：别人求最优性，我们只复算

`maxsat-verify` 验的是自己算出的那一对；`maxsat-verify-external` 把两端都换成外部输入。

| 步骤 | 谁做 |
| --- | --- |
| `maxsat-cnf <wcnf> <opt>` 导出「代价 ≤ opt」的编码，外部求解器求得模型 | 外部 |
| `maxsat-cnf <wcnf> <opt-1>` 导出「代价 ≤ opt-1」的编码，外部求解器判 UNSAT 并写 DRAT | 外部 |
| `maxsat-verify-external` 重算赋值代价、重放证明 | 本项目 |

CaDiCaL 3.1.0 实测（native release）：

| 实例 | opt | 外部证明 | 两端复算 | 自家 `maxsat-verify` |
| --- | --- | --- | --- | --- |
| Petersen 最小顶点覆盖（10 顶点，软权重 100） | 6 | 263 字节 / 14 行 | 5–10 ms | 5 ms |
| 10×10 网格（100 顶点，软权重 1） | 50 | 22331 字节 / 2835 行（编码 5150 变量） | 62 ms | 约 345 ms |

Petersen 太小，两边开销都在编码重建上，量级相同；10×10 才拉开约 5 倍，因为自家那条路径要自己求两档最优值。两份外部证明交给 `drat-trim` 也都是 `s VERIFIED`、0 RAT 引理。这一步把关系补成双向：外部检查器能验我们的证明，我们也能验外部的证明与赋值，最优性不依赖任何一方。

一个操作细节：`proof` / `maxsat-proof` 的输出首行是 `s UNSATISFIABLE …`，`drat-trim` 不接受，喂之前 `grep -v '^s '` 去掉；`maxsat-cnf` 的输出是纯 DIMACS，不用处理。

## 顺带修掉的一个坑

0.6.5 到 0.7.5 命令行不接受文件路径（MoonBit core 没有文件系统模块，公式一律内联传入），路径参数会被挡下；0.7.6 起 `@路径` 成了正规入口，读盘由官方 `moonbitlang/x/fs` 完成，不以 `@` 开头的路径仍然挡下。更早的版本（0.6.4 及以前）则把路径当文本扫数字：`proof examples/pigeonhole-3-2.cnf` 会从文件名里抠出 `3` 和 `2`，造出一个小公式，然后打印 `s SATISFIABLE`。对求解器来说这是最坏的失败模式——不是报错，是给一个自信的错误答案。0.6.5 起这类参数被挡下：

```
c error: the formula argument looks like a file path; pass @path to read it from disk, or inline it with "$(cat file)"
```

判定很窄：参数里没有 `p cnf` / `p wcnf` 头，同时含 `/`、`\`、`.cnf`、`.wcnf` 才拦。正常的内联公式不受影响；`@` 开头的参数在读盘之前就被单独处理，不会被这条判定误伤。

## 结论对拍：1400 个随机 3-SAT

上面的交叉验证比的都是「证明」这一侧：同一批 DRAT 交给别的检查器。但证明再准，如果求解器本身把 SAT 判成 UNSAT，错误也会一路带进证明（那份证明根本产不出来，或者产出来验不过）。所以还需要一个独立结论源：`CaDiCaL 3.1.0`。

`tools/difftest.sh` 生成随机 3-SAT，双方各跑一遍，比的不只是结论，还有见证：

| 结论 | 还要核什么 | 谁核 |
| --- | --- | --- |
| 双方都 SAT | 我们的 `v` 行是否满足每一条子句 | `tools/check_model.py`（不依赖任何求解器，纯 DIMACS 解析） |
| 双方都 UNSAT | 我们的 DRAT 是否被接受 | `drat-trim`（664 个 UNSAT 全部核） |
| 结论不同 | 记下实例，退出码非 0 | 脚本本身 |

实例由 `tools/gen3sat.py` 按固定种子生成，子句数 = `round(ratio × vars)`，两条比例线：4.26（阈值附近，SAT 与 UNSAT 都大量出现）与 5.00（偏 UNSAT）。单实例 20 秒上限，超时单独计数、不算通过。

结果（Linux 云主机、native release、单进程）：

| 变量 | 比例 | 实例 | SAT | UNSAT | 结论一致 | 分歧 | 超时 | 坏模型 | 坏证明 | 证明已核 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20 | 4.26 | 200 | 135 | 65 | 200 | 0 | 0 | 0 | 0 | 65 |
| 30 | 4.26 | 200 | 135 | 65 | 200 | 0 | 0 | 0 | 0 | 65 |
| 40 | 4.26 | 200 | 123 | 77 | 200 | 0 | 0 | 0 | 0 | 77 |
| 50 | 4.26 | 200 | 125 | 75 | 200 | 0 | 0 | 0 | 0 | 75 |
| 60 | 4.26 | 200 | 116 | 84 | 200 | 0 | 0 | 0 | 0 | 84 |
| 20 | 5.00 | 100 | 22 | 78 | 100 | 0 | 0 | 0 | 0 | 78 |
| 30 | 5.00 | 100 | 14 | 86 | 100 | 0 | 0 | 0 | 0 | 86 |
| 40 | 5.00 | 100 | 9 | 91 | 100 | 0 | 0 | 0 | 0 | 91 |
| 80 | 4.26 | 50 | 26 | 24 | 50 | 0 | 0 | 0 | 0 | 24 |
| 100 | 4.26 | 50 | 31 | 19 | 50 | 0 | 0 | 0 | 0 | 19 |

合计 1400 个实例：**1400/1400 结论一致，736 个 SAT 模型全部满足公式，664 份 UNSAT 证明全部 `s VERIFIED`，0 分歧、0 超时、0 坏见证**。

全量核证明并不贵：这些随机 3-SAT 的证明都很短，664 份交给 `drat-trim` 的总开销约 50 秒（实测 40 份 3.0 s，单份耗时由进程启动主导，而不是证明长度），所以默认就是全验，不再抽样；想只抽样时给 `PROOF_SAMPLE=20`。

复跑只要三个命令：

```bash
moon build --target native --release
bash tools/difftest.sh                       # 默认 10 档 1400 个实例，UNSAT 证明全验
TIERS="40:4.26:300" bash tools/difftest.sh   # 只跑一档
```

边界也要写清楚：只覆盖随机 3-SAT，不含工业实例、不含带大量 unit 或结构化的公式；CaDiCaL 用默认参数，没有调参对齐。

## 加权最优值：与暴力枚举对拍 400 个实例

上面两件事都没有回答「`maxsat` 报的 `o` 到底是不是真最小值」：结论对拍只比 SAT/UNSAT，证明对拍只验证明被接受，`maxsat-verify` 验的是我们自己的 `o` 与自己的证明彼此一致——两样东西一起错时它看不出来。所以再补一个从第一性原理出发的裁判：枚举全部赋值，算出真最小值。

`tools/maxsat_bruteforce.py` 自己生成随机 WCNF，用 `maxsat @file` 求最优，再把 2^n 个赋值全跑一遍取最小软代价（硬子句不满足的赋值直接跳过）。硬子句按「先随机取一个见证赋值，再让每条硬子句都由它满足」的方式构造，保证实例一定可行。权重取自 {1,2,3,5}，总量小，不触 `weight_cap`。

| 变量 | 软子句 | 硬子句 | 实例 | 最优值相等 | 不等 | 求解失败 |
| --- | --- | --- | --- | --- | --- | --- |
| 8 | 24 | 0 | 100 | 100 | 0 | 0 |
| 10 | 30 | 4 | 100 | 100 | 0 | 0 |
| 12 | 36 | 6 | 100 | 100 | 0 | 0 |
| 12 | 34 | 20 | 50 | 50 | 0 | 0 |
| 14 | 42 | 8 | 40 | 40 | 0 | 0 |
| 16 | 48 | 0 | 10 | 10 | 0 | 0 |

合计 **400/400 最优值等于暴力枚举结果，0 不等、0 求解失败**。整轮 400 个实例（含 2^16 的全枚举与 400 次求解）实测 9.4 秒，所以这个对拍可以随时复跑，不需要攒着做。

```bash
python3 tools/maxsat_bruteforce.py --main ./_build/native/release/build/cmd/main/main.exe
```

边界：规模卡在 16 个变量，因为要枚举 2^n；只覆盖随机小实例，不覆盖结构化实例（网格、Petersen 这类在 `benchmarks.md` 里是手工对拍过的）；不含 `maxsat-oll` 的核心引导路径——它复用同一套编码与最优值判定，但没有单独枚举对拍过。

## 没有做到的

- 核心引导路径（`maxsat_oll`）不导出下界证明，所以外部检查覆盖的是编码路径的「上下界」证明，不是核心引导每一轮 core 的可移植证明。
- 外部样本只有一个求解器、两个实例：CaDiCaL 3.1.0 对鸽巢 6/5 与 7/6 写出的都是纯 DRUP，`verify-rat` 的 RAT 分支仍无真实外部证据；SAT Competition 的官方证明集多是 kissat/cadical 的大实例，没有整包对比。
- k=10 的鸽巢能生成证明，但本项目自己的检查器仍比 `drat-trim` 慢数倍：0.7.4 同机端到端 277.5 s（其中求解 207.7 s、纯校验约 70 s），0.7.6 对已有证明 `verify @cnf @drat` 整条 89 s（含读盘与解析）。`drat-trim` 本身对这种规模没有压力，所以这里的瓶颈是我们，不是外部工具。
