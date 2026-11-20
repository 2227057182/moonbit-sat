# 证明格式与校验

本项目的 UNSAT 证明是一份 DRAT 文本的子集：只使用 RUP 步骤，不产生 RAT 步骤。这份文档说明格式、校验算法，以及它与完整 DRAT 的差别。

## 行格式

每行一条步骤，以一串整数表示字面、以 `0` 结尾。变量按 1 基编号，负号表示取反。

```
-1 0          # 添加子句 (¬x1)
d 3 -4 0      # 删除子句 (x3 ∨ ¬x4)
0             # 添加空子句，即矛盾
```

三类行：

| 形式 | 含义 |
| --- | --- |
| `<lits> 0` | 添加子句 |
| `d <lits> 0` | 删除子句（内容匹配） |
| `0` | 添加空子句，证明结束 |

## RUP 的定义

子句 `C` 是当前子句池的 RUP 推论（reverse unit propagation consequence），当且仅当：

把 `C` 中每个文字取反、当作已赋值为真，然后在子句池上反复做单位传播，最终产生冲突。

换句话说：假设 `C` 为假会导致矛盾，所以 `C` 必须是原公式的逻辑推论。

注意极性的方向：对 `C` 中的文字 `l`，要假设的是 `¬l` 为真。写反了会把伪证明判为通过——这是本项目真实踩过的坑，`checker.mbt` 的 `rup_check` 里保留了这条注释。

## 校验算法

```
pool   ← 原公式的全部子句
alive  ← 全部为 true
saw_empty ← false

对每条步骤：
  若为删除：在 pool 中找到内容相同且 alive 的第一条，标记 alive = false
  若为添加：
    若 rup_check(pool, alive, C) 失败 → 返回 false
    把 C 加入 pool，alive = true
    若 C 为空子句 → saw_empty = true

返回 saw_empty
```

`rup_check` 每次从「候选子句取反后的初始赋值」开始跑一遍传播。它不复用求解器状态，但会复用检查器自己的监听结构：`CheckDb` 按文字维护监听列表，`propagate` 只访问被置假文字对应的那一条，不再逐条扫描整个池。

回滚范围是确定的：单元子句构成 trail 的基座层（`base_len` 之前），`reset` 只撤销假设层之上的赋值，监听列表完全不动。监听只记录「某条子句正在监听哪两个文字」，与临时假设无关，因此可以跨步骤复用。

复杂度从「步数 × 子句池规模 × 传播轮数」降到「步数 × 实际触发的监听数」：前者每步都要把整池扫一遍，后者只走真正被影响的子句。

下面是 native release 下的实测，证明行数在改造前后完全相同：

| k | 变量 | 证明行数 | 改造前 | 改造后 |
| --- | --- | --- | --- | --- |
| 7 | 42 | 670 | 0.04s | 0.02s |
| 8 | 56 | 3942 | 0.66s | 0.16s |
| 9 | 72 | 40273 | 32.56s | 5.96s |

行数 ×10 时改造前耗时 ×50，改造后 ×37。k=10（295345 行、90 变量）仍需约 350s：这类鸽巢证明的子句数远多于变量数，平均每个文字挂着数千条监听，传播本身成为主要成本。这个上限是结构性的，进一步提速需要更强的 RUP 复算调度，而不是继续改监听结构。

## 判失败的三种情况

1. 某条添加子句不是 RUP 推论。
2. 证明结束时没有出现空子句。
3. 文本里出现无法解析的步骤（例如 RAT 使用的子句语法，本实现不接受）。

返回 `false` 只说明「这份证明没有支撑 UNSAT 结论」，不说明公式可满足。

## 与完整 DRAT 的差别

| 项目 | 完整 DRAT | 本实现 |
| --- | --- | --- |
| RUP 步骤 | 支持 | 支持 |
| RAT 步骤 | 支持 | **不支持**，遇到判失败 |
| 删除语义 | 宽松（找不到可忽略） | 宽松（同左） |
| 变量编号 | 1 基 | 1 基 |
| 子句顺序 | 无要求 | 无要求 |

不支持 RAT 是有意的：CDCL 核心只产生 RUP 步骤，支持 RAT 会引入没有测试覆盖的分支，反而降低可信度。如果将来接入 RAT 生成能力，校验器需要单独加分支与对拍。

## 一次真实运行的证明

实例：3 只鸽子 2 个洞（`examples/pigeonhole-3-2.cnf`）。

```
s UNSATISFIABLE
-1 0
0
```

求解器先学到单位子句 `¬x1`，再推出空子句。把这两行交给 `verify`，RUP 检查逐条通过：

```
moon run cmd/main -- proof  "p cnf 6 9;1 2 0;3 4 0;5 6 0;-1 -3 0;-1 -5 0;-3 -5 0;-2 -4 0;-2 -6 0;-4 -6 0"
moon run cmd/main -- verify "p cnf 6 9;..." "-1 0;0"
```

第二条命令输出 `s VERIFIED`。把证明换成任意一条非 RUP 的子句（例如可满足实例上的 `1 0;0`），输出 `s PROOF-REJECTED`。

## MaxSAT 最优性的证明

到这里，能独立复算的只有 SAT 判定。MaxSAT 的最优值此前是求解器的内部断言：二分一旦收敛，`o <cost>` 就只是求解器自己说的话。

补法是把它落回 SAT：判断「软子句代价不超过 `k` 是否可行」本身就是一个 CNF（`maxsat_encoding`）。于是最优性拆成两半：

- 下界：`k < opt` ⇔ 该 CNF 不可满足 ⇔ 可以导出一份 DRAT 证明；
- 上界：给出一个赋值，它的代价按 WCNF 原文重算恰好等于 `opt`。

只走通一半都会留下漏洞。没有下界，`opt` 可能偏大——也许存在更便宜的解而求解器没找到；没有上界，`opt` 可能偏小——求解器说「更便宜不可达」，但没有任何东西证明那个偏小的值真的付得起。所以两条都要。

### 下界：`opt-1` 不可达

```
moon run cmd/main -- maxsat-proof "p wcnf ..." 5      # 打印 k=5 的 DRAT 证明
moon run cmd/main -- verify-maxsat  "p wcnf ..." 5 "<DRAT 文本>"   # 重建编码后重放
```

### 上界：一个真的达到 `opt` 的赋值

`maxsat_solution(w, cap)` 在拿到最优值后用同一份 `maxsat_encoding(w, opt)` 再解一次，把 model 截回原始变量数。代价不是求解器顺手报的数：`maxsat_model_cost` 只按 WCNF 原文走一遍——硬子句有任何一条不满足就返回 `-1`，否则累加被违反软子句的权重。它不读求解器的任何中间状态，所以这个数可以脱离求解过程复算。

```
moon run cmd/main -- maxsat-solution "p wcnf ..."                  # o <cost> / v ... 0 / s SOLUTION-VERIFIED
moon run cmd/main -- verify-solution "p wcnf ..." 6 "v 1 -2 3 4 -5 6 7 -8 -9 10 0"
```

`verify-solution` 只吃外部给的代价与赋值：解析成完整赋值数组（未提到的变量按假），再复算。第三方拿到 `o` 与 `v` 两行就能自己判，不需要信任求解过程，也不需要本库先跑一遍最优性搜索。

### 一条命令验两端

```
moon run cmd/main -- maxsat-verify "p wcnf ..."
```

先求 `opt`，再分别算上界与下界，输出 `o <cost>`、`c upper= <bool> lower= <bool>`，两端皆真才给 `s OPTIMALITY-VERIFIED`。四个基准实例（native release）：

```
o 6   c upper= true lower= true  s OPTIMALITY-VERIFIED      # Petersen
o 10  c upper= true lower= true  s OPTIMALITY-VERIFIED      # 4×5 网格
o 1   c upper= true lower= true  s OPTIMALITY-VERIFIED      # scheduling
o 50  c upper= true lower= true  s OPTIMALITY-VERIFIED      # 10×10 网格，347ms
```

### 边界：这是「可复算」，不是「零依赖」

证明是对**扩展后的 CNF**给出的：里面多了每条软子句的 select 变量，以及 Sinz 计数编码分配的一批变量。校验方必须用同一个 `maxsat_encoding` 重建这份公式，才能重放 DRAT。

这比「信求解器」强得多，但和 SAT 侧的性质不同：SAT 侧 `verify` 拿的是原始 CNF，任何人手上有那份 CNF 就能验；MaxSAT 侧验的是编码后的实例，编码器是前提。所以准确的措辞是**可复算**——把实例和 `k` 交给库，它会确定性重建出同一份公式（同样的输入必然得到同样的变量编号与子句顺序），然后逐条重放。编码器本身是公开源码，不存在「信一个黑箱」。

上界那一半没有这个前提：代价是直接在 WCNF 上算的，任何能读 WCNF 的人都能复核；受本库语义约束的只有 `top` 阈值与重复权重的累加方式这两条。

### 篡改实验

证明侧（Petersen，`k=5`，证明共 14 行，末尾是空子句）：

```
... 65 0
0
```

- 原样交给 `verify-maxsat` → `s VERIFIED`
- 删掉末尾那行 `0` → `s PROOF-REJECTED`（校验器要求证明以空子句收尾）
- 拿同一份证明换一个 `k` 去验 → `s PROOF-REJECTED`（编码随 `k` 改变，证明不再对应；测试里对 `k=0` 与 `k=1` 做过这条）

赋值侧（Petersen，`o 6`，`v 1 -2 3 4 -5 6 7 -8 -9 10 0`）：

- 原样回放 → `s SOLUTION-VERIFIED`
- 把 `3` 翻成 `-3` → `s SOLUTION-REJECTED`（代价变了，与声称的 `6` 不符）
- 声称代价改成 `5` → `s SOLUTION-REJECTED`
- 全部置假 → `s SOLUTION-REJECTED`（硬子句对应的边没有顶点覆盖）

### 已知缺口

- `maxsat-verify` 仍是「自己算 + 自己验」：它先 `maxsat_solve` 求 `opt`，再用同一个二分取赋值。第三方不跑求解器时，拿 `o`/`v` 与下界证明两份文本分别走 `verify-solution` 与 `verify-maxsat` 即可，这两条路径都已提供；但没有一条命令能同时接收「外部 `o`/`v` + 外部证明」并把 `opt` 也当成外部断言来验。
- 证明规模随 `k` 与权重重复数增长：权重 100 的软子句会在松弛数组里出现 100 次，Sinz 编码随之变大。权重上限由 `maxsat_solve` 的 `weight_cap` 挡着，不是静默截断。
- 没有把最优性证明接到外部工具链（drat-trim 等）。外部工具不认识本库的编码，需要先落地一份 CNF；这条留给 roadmap。
- 完整 OLL/WPM1 需要的权重拆解未实现，因此大权重实例的编码体积仍然不可控。


如果检查器复用求解器的数据结构，一个错误的传播实现会让求解器与检查器同时出错，两边一致地给出错误结论，校验就失去意义。

因此 `checker.mbt` 不引用 `solver.mbt`：它自带子句池、自带赋值数组、自带传播循环。两者只有 `Lit` 编码与 `Formula` 解析是共享的，而这两部分的正确性由对拍测试守着。
