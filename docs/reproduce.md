# 复现

从空目录开始，八节命令就能看到本项目的全部证据。默认 Linux/macOS 的 shell，Windows 把 `$(cat 文件)` 换成 `Get-Content` 或直接把文本拼成一行。

## 前置

MoonBit 工具链（`moon` 在 PATH 里）；native 目标需要一个 C 编译器（`gcc` / `clang` / `cc` 任一）。wasm 与 js 目标不需要。

```bash
git clone https://github.com/2227057182/moonbit-sat.git
cd moonbit-sat
moon check --deny-warn     # 0 warnings
moon test                  # 67 passed, 0 failed
moon build --target native --release
M=_build/native/release/build/cmd/main/main.exe
```

`moon test --target js` 是同一套测试在 js 后端的结果，数字一样。

命令行不接受文件路径：公式与证明都内联传入，`;` 等价于换行。这是 MoonBit core 目前没有文件系统模块导致的限制，`docs/api.md` 里有说明。

## 1. 判定

```bash
$M solve "p cnf 2 2;1 2 0;-1 0"
```

```
s SATISFIABLE
v -1 2 0
c decisions=0 propagations=2 conflicts=0 restarts=0 learnts=0 minimised=0
```

`(x1 ∨ x2) ∧ ¬x1` 唯一的解是 `x1=false, x2=true`，所以 `v` 行是 `-1 2`。

## 2. 证明

```bash
$M proof "$(cat examples/pigeonhole-3-2.cnf)"
```

```
s UNSATISFIABLE
-1 0
0
```

3 鸽 2 洞：先学到单位子句 `¬x1`，再学到空子句。`0` 单独一行是空子句，也是检查器判定「证明完整」的标志。

## 3. 校验

```bash
$M verify "$(cat examples/pigeonhole-3-2.cnf)" "-1 0
0
c decisions=1"
```

```
s VERIFIED
```

末尾那行 `c …` 是故意留的：真实证明文件常带注释行，解析器会跳过它们而不是当成子句。0.6.4 之前这里会 abort（注释行里的数字被当成字面），0.6.4 起不会，`checker_comment_wbtest.mbt` 守着这条。

把证明改成伪造的（比如删掉 `0` 那行），会得到 `s PROOF-REJECTED`。

## 4. core

```bash
$M core "p cnf 2 2;1 2 0;-1 -2 0" "1 2"
```

```
s UNSATISFIABLE
c core= 1 2 0
```

两条假设同时成立时不可满足，返回的 core 就是这两条本身。

## 5. 加权优化

```bash
$M maxsat "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"
```

```
o 1
s OPTIMUM FOUND
```

硬子句要求至少一个变量为真，两条权重 1 的软子句要求两者都为假，最小违约成本是 1。

## 6. 最优性两端

```bash
$M maxsat-verify "$(cat examples/petersen-mwvc.wcnf)"
```

```
o 6
c upper= true lower= true
s OPTIMALITY-VERIFIED
```

`upper` 是「存在一个代价恰为 6 的赋值且按 WCNF 原文复算通过」，`lower` 是「代价 5 不可达的 DRAT 证明重建后校验通过」。两端都为真才给 `OPTIMALITY-VERIFIED`。

拿到的赋值可以单独导出并交给别人复核：

```bash
$M maxsat-solution "$(cat examples/grid-mwvc.wcnf)"
```

```
o 10
v 1 -2 3 -4 5 -6 7 -8 9 -10 11 -12 13 -14 15 -16 17 -18 19 -20 0
s SOLUTION-VERIFIED
```

```bash
$M verify-solution "$(cat examples/grid-mwvc.wcnf)" 10 "v 1 -2 3 -4 5 -6 7 -8 9 -10 11 -12 13 -14 15 -16 17 -18 19 -20 0"
```

```
s SOLUTION-VERIFIED
```

把 `v` 行里任意一个变量翻过来，或把代价改成 9，都会变成 `s SOLUTION-REJECTED`。

## 7. 压力与规模

```bash
$M bench
```

五行 `c bench vars=… clauses=… result=… decisions=…`，实例由内置线性同余发生器生成、种子写死，任何机器上结果一致。

```bash
$M bench-verify 9
```

```
c verify k=9 vars=72 proof_lines=40273 sat=false result=VERIFIED
```

9 鸽 8 洞：72 个变量、40273 行证明，进程内构造、求解、再逐条 RUP 校验，大约 6 秒。这一步绕开了命令行参数长度上限，因为 4 万行证明塞不进一个参数。

## 8. 外部交叉验证

前面七步用的都是本项目自己的检查器。最后一步把同一批证明交给两个与项目没有共享代码的 C 检查器：

```bash
bash tools/crosscheck.sh
```

脚本自动下载并 `gcc -O2` 编译 `drat-trim` 与 `lrat-check`，然后对 10 个案例复算（鸽巢 3–9 洞，以及 Petersen、10×10 网格、排班三个加权实例的 `opt-1` 不可达证明）；`BIG=1` 再追加鸽巢 10/9（295345 行）与 20×20 网格下界，共 12 个案例：

```
case             lemmas  drat-trim    lrat-check
php 3/2             2    s VERIFIED   c VERIFIED
php 9/8         40273    s VERIFIED   c VERIFIED
petersen-mwvc k=5  13    s VERIFIED   c VERIFIED
```

最后一行是 `all cases verified by drat-trim and lrat-check`，任一案例失败则退出码非 0。`drat-trim` 的分项统计显示全部案例 **0 RAT 引理**，即输出证明是纯 DRUP，只需 RUP 就能验。方法和完整表格见 [docs/crosscheck.md](crosscheck.md)。

反方向的一半也在默认测试里：xternal_proof_wbtest.mbt 把 CaDiCaL 3.1.0 对鸽巢 6/5 写出的 235 行证明原样交给本项目检查器，erify 与 erify-rat 都判通过，删掉末尾空子句即被拒绝；这一步不需要装 CaDiCaL，见 [docs/crosscheck.md](crosscheck.md)「反方向」。

## 参考耗时

Ubuntu 云主机、native release、单次运行（含进程启动）：

| 命令 | 耗时 |
| --- | --- |
| `solve` / `core` / `maxsat`（小实例） | < 10 ms |
| `maxsat-verify` Petersen、4×5 网格、scheduling | 6 ms |
| `maxsat-verify` 10×10 网格（100 变量） | 347 ms |
| `bench-verify 9` | 约 6 s |
| `bench-verify 10` | 约 280 s；旧记录 350 s（机器不同，见 `docs/benchmarks.md`「0.7.4 同机复跑」） |

数字随机器浮动，量级应当一致。
