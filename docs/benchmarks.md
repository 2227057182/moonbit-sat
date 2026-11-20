# MaxSAT 基准与对比

## 为什么用顶点覆盖

最小顶点覆盖是 MaxSAT 评测里的经典家族：每条边一条硬子句 `(u v)`（至少选一个端点），每个顶点一条软子句 `(-v)` 权重 1（选它付 1）。代价即覆盖大小，编码不需要任何人工调参，也不会因为「构造得好」而让结果好看。

## 实例与已知最优

| 实例 | 图结构 | 变量 | 硬子句 | 软子句 | 已知最优 | 依据 |
| --- | --- | --- | --- | --- | --- | --- |
| `examples/petersen-mwvc.wcnf` | Petersen 图 | 10 | 15 | 10 | 6 | 下界论证（见下） |
| `examples/grid-mwvc.wcnf` | 4×5 网格 | 20 | 31 | 20 | 10 | König 定理 |
| `grid-wcnf 6 6` | 6×6 网格 | 36 | 60 | 36 | 18 | König 定理 |
| `grid-wcnf 10 10` | 10×10 网格 | 100 | 180 | 100 | 50 | König 定理 |
| `examples/scheduling.wcnf` | 2 任务 2 槽 | 4 | 4 | 3 | 1 | 手工构造 |

**Petersen 图最优 6。** 下界：一个 5 顶点覆盖要覆盖 15 条边，而每个顶点最多覆盖 3 条，5×3 = 15 恰好用满，说明选中的 5 个顶点之间不能有边（否则那条边被数两次，必然有边漏掉）；但 Petersen 图的独立数是 4，不存在 5 顶点独立集，所以 5 不可行，最优 ≥ 6。上界：求解器返回代价 6 的赋值。

**网格图最优 = 最大匹配。** 网格是二分图（按棋盘黑白染色），König 定理给出「最小顶点覆盖 = 最大匹配」。n×m 网格的最大匹配是 ⌊nm/2⌋，所以 4×5 是 10、6×6 是 18、10×10 是 50。这条依据与求解器完全独立。

**scheduling 最优 1。** 两条关于 task1 的软偏好互斥，无论怎么分配至少违反一条，权重最小为 1，且存在只违反它的分配。

## 实测

native release，Ubuntu 云主机，每个实例跑 5 次取最小值（含进程启动）：

| 实例 | 变量 | 求解器输出 | 耗时 |
| --- | --- | --- | --- |
| `petersen-mwvc.wcnf` | 10 | `o 6` | 1.1 ms |
| `grid-mwvc.wcnf` | 20 | `o 10` | 1.7 ms |
| `grid-wcnf 6 6` | 36 | `o 18` | 10 ms |
| `grid-wcnf 10 10` | 100 | `o 50` | 160 ms |
| `scheduling.wcnf` | 4 | `o 1` | 0.8 ms |

五个实例的返回值都与已知最优一致，没有一次偏差。耗时随规模上升，但绝对值仍在百毫秒级——这组实例是用来钉住「最优值正确」的，不是压性能的。

双端最优性校验（`maxsat-verify`，含求最优 + 取赋值 + 复算代价 + 导出并校验 `opt-1` 的证明）：

| 实例 | `c upper` / `c lower` | 耗时 |
| --- | --- | --- |
| `petersen-mwvc.wcnf` | `true` / `true` | 6 ms |
| `grid-mwvc.wcnf` | `true` / `true` | 6 ms |
| `scheduling.wcnf` | `true` / `true` | 6 ms |
| `grid-wcnf 10 10` | `true` / `true` | 347 ms |

10×10 这一行比单求解贵一倍多：`opt-1` 的编码要额外分配约 5000 个 Sinz 变量，证明生成与重放都在这个规模上做。其余三个实例的两端校验与单次求解基本同价。

## 复现

```bash
moon build --target native --release
cd _build/native/release/build/cmd/main
./main grid-wcnf 10 10 | grep -v '^c' | paste -sd';' > /tmp/g
./main maxsat "$(cat /tmp/g)"
./main maxsat-verify "$(cat /tmp/g)"      # 两端校验
./main maxsat-solution "$(cat /tmp/g)"    # o + v 行，可交给 verify-solution
```

仓库里已有的两个实例同理：去掉注释行、用 `;` 拼成一行传给 `maxsat`。

## 局限

- 对比对象是「经典图结构 + 理论已知最优」，不是 MaxSAT Evaluation 的参赛求解器；没有在与工业求解器相同的数据集上比较。
- 最大规模 100 个变量，只能说明趋势，不能说明在大实例上的竞争力。
- 加权（权重不是全 1）的公开实例没有覆盖，加权能力由 `scheduling.wcnf` 与 `maxsat_core_wbtest.mbt` 里的权重实例覆盖。
