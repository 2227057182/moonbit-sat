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

两行的耗时分别是约 17 s 与约 0.5 s。k=10 那行最能说明外部工具的价值：本项目自己的检查器要 350 秒，`drat-trim` 约 17 秒、`lrat-check` 约 0.7 秒，差距 20 倍，但结论完全一致。20×20 那行的证明只有 8622 行，`drat-trim` 253 毫秒就验完了——慢的从来不是证明，是我们自己的检查器。

这两行不放在默认脚本里（k=10 要先跑 223 秒求解），用 `BIG=1 bash tools/crosscheck.sh` 单独触发。
两点值得单独说明。

**全部案例都是 0 RAT 引理。** 也就是说本项目输出的证明是纯 RUP（DRUP）：每条学到的子句都能靠单元传播从已有子句推出冲突，不需要 RAT 的「对该文字所有子句做 resolvent」那套机制。这让外部检查的门槛降到最低——任何只支持 DRUP 的检查器也能用。项目里的 `verify-rat` 是为读别人的证明准备的，不是为自己输出准备的。

**加权部分现在也能交给外部检查器。** 以前 `maxsat_bound_proof` 只能用自己的检查器复验，因为编码后的 CNF 没有导出入口，外人拿不到「公式」。0.6.5 起 `maxsat-cnf <wcnf> <k>` 直接打印 `maxsat_encoding(w, k)` 的 DIMACS，于是「最优性下界」也能走 `drat-trim` + `lrat-check`：拿到的公式和证明都来自本项目，判定则由第三方给出。

```bash
# 公式与证明分开取，交给任意 DRAT 检查器
M=_build/native/release/build/cmd/main/main.exe
$M maxsat-cnf "$(cat examples/petersen-mwvc.wcnf)" 5 > enc.cnf
$M maxsat-proof "$(cat examples/petersen-mwvc.wcnf)" 5 | grep -E '^(-?[0-9]|d )' > bound.drat
drat-trim enc.cnf bound.drat
```

`maxsat-cnf 5` 的语义是「软代价 ≤ 5 是否可行」，`petersen` 的最优代价是 6，所以这个公式不可满足，它的证明才构成最优性下界的证据。取 `k = opt` 时公式可满足，`maxsat-proof` 会返回 `s SATISFIABLE (cost <= opt achievable)` 而不是证明——这一点也是可验证的。

## 顺带修掉的一个坑

命令行不接受文件路径（MoonBit core 没有文件系统模块，公式一律内联传入）。但早期版本把路径当文本扫数字：`proof examples/pigeonhole-3-2.cnf` 会从文件名里抠出 `3` 和 `2`，造出一个小公式，然后打印 `s SATISFIABLE`。对求解器来说这是最坏的失败模式——不是报错，是给一个自信的错误答案。0.6.5 起这类参数被挡下：

```
c error: the formula argument looks like a file path; formulas are passed inline, so expand it first with "$(cat file)"
```

判定很窄：参数里没有 `p cnf` / `p wcnf` 头，同时含 `/`、`\`、`.cnf`、`.wcnf` 才拦。正常的内联公式不受影响。

## 没有做到的

- 完整 OLL / WPM1 仍未实现，所以外部检查覆盖的是本项目这套「上下界 + 编码」路线的最优性证明，不是 MaxSAT 评测里任意 WCNF 的最优性。
- 没有和 SAT Competition 的官方证明集对比：那些实例的证明由别的求解器产生，用它们的证明喂本项目检查器属于另一件事，见 [proof.md](proof.md) 里的篡改实验。
- k=10 的鸽巢能生成证明，但本项目自己的检查器要 350 秒（每个文字挂数千条监听的结构性问题，见 [roadmap.md](roadmap.md)）；`drat-trim` 本身对这种规模没有压力，所以这里的瓶颈是我们，不是外部工具。
