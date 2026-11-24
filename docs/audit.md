# 十分钟审计

这一页只做一件事：让评审不用读完所有文档，就能把验收条目逐条核对一遍。每条给出**一条命令、一个预期输出、以及输出不符时意味着什么**。

命令按 Linux/macOS（或 WSL）的 bash 写；在 Windows PowerShell 里，`| wc -l` 换成 `| Measure-Object -Line`，其余命令不变。

## 前置（约 2 分钟）

```bash
git clone https://github.com/2227057182/moonbit-sat.git
cd moonbit-sat
moon check --deny-warn     # 期望：0 warnings
moon test                  # 期望：95 passed, 0 failed
```

`moon test` 在任意后端都能跑（`--target js` / `wasm` / `wasm-gc` 各 95/95）。若出现告警，说明仓库当前状态与「零告警」的口径不符，这本身就是问题。

## 1. MoonBit 为主

```bash
grep -rn 'extern "' --include=*.mbt --exclude-dir=.mooncakes --exclude-dir=_build . | wc -l   # 期望：0
cat moon.mod                                   # deps 只有 CLI 用的 moonbitlang/x
```

没有手写 FFI，没有链接任何外部求解器；求解、检查、优化都在 MoonBit 内完成。`moonbitlang/x` 只服务 `cmd/main` 的 `@path` 读盘，库包 `deps` 为空。

`.mooncakes/` 是依赖缓存、`_build/` 是生成物，两者都不在仓库里（`git ls-files '*.mbt'` 只有 24 个文件），直接 `grep -rn` 会把它们算进去（166 行），所以命令里带了两个 `--exclude-dir`。

**不符时**：若出现 `extern` 或 `moon.mod` 里多了求解器相关的依赖，「纯 MoonBit」这条就不再成立。

## 2. 提交可追踪

```bash
git log --oneline | head -5
git log --since=2026-11-01 --oneline | wc -l   # 十一月起的提交数，自己数
git tag | tail -8                              # 每个发布版本一个 tag
```

每个发布版本都有 tag 与 GitHub Release；十一月起的每次提交在上面第二条命令里可见。

## 3. 能运行

```bash
moon build --target native --release
./_build/native/release/build/cmd/main/main.exe solve "p cnf 3 2;1 2 0;-1 0"
```

期望最后三行：`s SATISFIABLE`、`v … 0`、`c decisions=… conflicts=…`。

编译不了 native（缺 C 编译器）？用 `moon run cmd/main -- solve ...`（wasm-gc 后端）同样可跑，只是拿不到 `@path` 读盘。

## 4. 工作有效

```bash
M=_build/native/release/build/cmd/main/main.exe
$M bench-verify 8                                   # 求解+校验鸽巢 8 鸽 7 洞，期望 result=VERIFIED
$M maxsat        "p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0"   # 期望 o 1 + s OPTIMUM FOUND
$M maxsat-verify @examples/petersen-mwvc.wcnf        # 期望 upper= true lower= true + OPTIMALITY-VERIFIED
```

三条分别覆盖：证明生成与校验闭环、加权优化、最优性两端复算。

想再往外交给第三方（需要 `gcc` 与网络，或预装的 `cadical`）：

```bash
bash tools/crosscheck.sh        # drat-trim + lrat-check 复算 10 个案例，最后一行 all cases verified
bash tools/difftest.sh          # 与 CaDiCaL 对拍 1400 个随机 3-SAT，期望 1400/1400 一致
```

## 5. 开源合规

```bash
head -3 LICENSE                  # Apache-2.0
grep -n "许可证\|许可" docs/origin.md | head -3
```

仓库内 MoonBit 代码为本项目原创；方法参考为公开论文与格式规范，逐条列在 `docs/origin.md`。无 GPL/AGPL 代码，无第三方求解器源码。

## 6. AI 可解释

不需要命令，读三页即可：

- `docs/design.md`：数据结构与关键不变量，包括「排序方向与注释相反」这种如实记录。
- `docs/roadmap.md`「不做」：明确列出拒绝的方向与理由（死槽复用、裁剪式复算、并行、totalizer）。
- `docs/fixes.md`：本季度真实出错的地方、怎么发现的、现在靠什么防复发。

## 一句话

如果六条里有任何一条命令的输出与上面写的不一致，那就是仓库的问题而不是文档的问题——请把那条命令的输出发出来，我按它修。
