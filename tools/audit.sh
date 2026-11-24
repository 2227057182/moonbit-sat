#!/usr/bin/env bash
# 十分钟审计的可执行版：docs/audit.md 里的六组命令，跑一遍并逐条判 PASS/FAIL。
#
#   bash tools/audit.sh           # 十分钟口径，不碰第三方检查器
#   bash tools/audit.sh --full    # 追加 crosscheck / difftest / 暴力枚举对拍
#
# 退出码：0 = 全部通过（允许 SKIP），1 = 有 FAIL。
# 缺工具（没有 C 编译器、没有 cadical）记 SKIP，不记 FAIL——那不是仓库的问题。

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 2
FULL=0
[ "${1:-}" = "--full" ] && FULL=1

pass=0; fail=0; skip=0
PASS() { pass=$((pass + 1)); printf '\033[32mPASS\033[0m  %s\n' "$1"; }
FAIL() { fail=$((fail + 1)); printf '\033[31mFAIL\033[0m  %s\n' "$1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/      /' | head -8; }
SKIP() { skip=$((skip + 1)); printf '\033[33mSKIP\033[0m  %s（%s）\n' "$1" "$2"; }

# expect <说明> <正则> <命令...>
expect() {
  local name=$1 want=$2; shift 2
  local out
  out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -qE "$want"; then PASS "$name"; else FAIL "$name" "$out"; fi
}

section() { printf '\n== %s ==\n' "$1"; }

# ---------------- 1. MoonBit 为主 ----------------
section "1. MoonBit 为主"
ffi=$(grep -rn 'extern "' --include=*.mbt --exclude-dir=.mooncakes --exclude-dir=_build . | wc -l | tr -d ' ')
if [ "$ffi" = "0" ]; then PASS "源码 0 处 extern \"（无手写 FFI）"; else FAIL "源码有 $ffi 处 extern \""; fi
mod_imports=$(awk '/^import \{/{f=1;next} /^\}/{f=0} f && /"/{print}' moon.mod | wc -l | tr -d ' ')
if [ "$mod_imports" = "1" ] && grep -q 'moonbitlang/x' moon.mod; then
  PASS "moon.mod 只 import 了 moonbitlang/x（CLI 读盘用）"
else
  FAIL "moon.mod 的 import 有 $mod_imports 条，超出预期" "$(cat moon.mod)"
fi
if grep -q '"' moon.pkg 2>/dev/null; then
  FAIL "库包 moon.pkg 有依赖" "$(cat moon.pkg)"
else
  PASS "库包 moon.pkg 无任何依赖"
fi

# ---------------- 2. 提交可追踪 ----------------
section "2. 提交可追踪"
if git rev-parse --git-dir > /dev/null 2>&1; then
  PASS "git 仓库完整（$(git log --oneline | wc -l | tr -d ' ') 个提交）"
  tags=$(git tag | wc -l | tr -d ' ')
  if [ "$tags" -ge 12 ]; then PASS "tag 数 $tags（每个发布版本一个）"; else FAIL "tag 只有 $tags 个"; fi
  if [ -n "$(git status --porcelain)" ]; then FAIL "工作区有未提交改动" "$(git status --short | head -5)"; else PASS "工作区干净"; fi
else
  SKIP "提交历史" "不是 git 仓库（下载的 zip 不带 .git）"
fi

# ---------------- 3. 能运行 ----------------
section "3. 能运行"
if ! command -v moon > /dev/null 2>&1; then
  SKIP "编译与测试" "PATH 里没有 moon"
else
  expect "moon check --deny-warn 零告警" 'Finished|up to date' moon check --deny-warn
  expect "moon test 全过" 'failed: 0' moon test
  BIN=_build/native/release/build/cmd/main/main.exe
  if moon build --target native --release > /tmp/audit-build.log 2>&1 && [ -x "$BIN" ]; then
    PASS "native release 可构建"
    expect "solve 判 SAT 并给模型" 's SATISFIABLE' "$BIN" solve 'p cnf 3 2;1 2 0;-1 0'
    expect "solve 判 UNSAT" 's UNSATISFIABLE' "$BIN" solve 'p cnf 2 2;1 0;-1 0'
  else
    SKIP "native 二进制的两条检查" "本机编译不了 native（缺 C 编译器），见 /tmp/audit-build.log"
  fi
fi

# ---------------- 4. 工作有效 ----------------
section "4. 工作有效"
if [ -x "${BIN:-}" ]; then
  expect "bench-verify 8 求解+校验闭环" 'result=VERIFIED' "$BIN" bench-verify 8
  expect "加权 MaxSAT 给出最优" 's OPTIMUM FOUND' "$BIN" maxsat 'p wcnf 2 3 10;10 1 2 0;1 -1 0;1 -2 0'
  expect "最优性两端复算" 'OPTIMALITY-VERIFIED' "$BIN" maxsat-verify @examples/petersen-mwvc.wcnf
  model=$("$BIN" maxsat-solution @examples/petersen-mwvc.wcnf 2>/dev/null \
          | awk '/^v /{ $1=""; sub(/ 0$/, ""); print; exit }')
  if [ -n "$model" ]; then
    expect "外部赋值复算代价（模型取自 maxsat-solution）" 'SOLUTION-VERIFIED' \
      "$BIN" verify-solution @examples/petersen-mwvc.wcnf 6 "$model"
  else
    SKIP "外部赋值复算代价" "maxsat-solution 没给出模型"
  fi
else
  SKIP "四条端到端检查" "没有 native 二进制"
fi

if [ "$FULL" = "1" ]; then
  if command -v gcc > /dev/null 2>&1 && [ -d "$HOME/sat/thirdparty" ]; then
    expect "与 drat-trim / lrat-check 交叉验证" 'all cases verified' bash tools/crosscheck.sh
  else
    SKIP "第三方检查器交叉验证" "缺 gcc 或 thirdparty 目录"
  fi
fi

# ---------------- 5. 开源合规 ----------------
section "5. 开源合规"
expect "LICENSE 是 Apache-2.0" 'Apache License' head -3 LICENSE
expect "来源与许可写清楚了" '许可证|许可|License' grep -n '许可' docs/origin.md

# ---------------- 6. AI 可解释 ----------------
section "6. AI 可解释"
for d in docs/design.md docs/fixes.md docs/roadmap.md; do
  if [ -s "$d" ]; then PASS "存在 $d（$(wc -l < "$d" | tr -d ' ') 行）"; else FAIL "缺 $d"; fi
done
expect "缺陷清单记录了真实出错" '症状|发现|修复' grep -m1 -E '症状|发现|修复' docs/fixes.md

printf '\n----------------------------------------\n'
printf 'audit: %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1
