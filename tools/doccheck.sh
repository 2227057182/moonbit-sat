#!/usr/bin/env bash
# 文档口径自查：把「文档里写的」与「仓库里是真的」逐条对上。
#
# 只做机械能判的四类。判不了的（一句话是否准确、表格是否自洽）还得人读，
# 这个脚本的价值是把「重复叙述」的地方标出来，让人只读真正需要判断的部分。
#
#   bash tools/doccheck.sh
#
# 事实全部从源码与仓库现读，脚本里不写死任何期望值——写死了就成了第五份
# 需要同步的数字。

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 2

fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'BAD   %s\n' "$1"; fail=$((fail + 1)); }
warn(){ printf 'warn  %s\n' "$1"; }

# ---------- 事实 ----------
CMDS=$(grep -oE 'cmd == "[a-z][a-z-]*"' cmd/main/main.mbt \
       | sed -E 's/.*"([a-z][a-z-]*)"/\1/' | sort -u)
VER=$(grep -m1 '^version' moon.mod | sed -E 's/.*"([^"]+)".*/\1/')
TESTS=$(grep -rhoE '^test "[^"]*"' --include=*.mbt \
        --exclude-dir=.mooncakes --exclude-dir=_build . | wc -l | tr -d ' ')
MBT=$(git ls-files '*.mbt' | wc -l | tr -d ' ')
DOCS=$(ls docs/*.md 2>/dev/null | wc -l | tr -d ' ')

printf 'facts: version=%s commands=%s tests=%s mbt=%s docs=%s\n\n' \
  "$VER" "$(printf '%s\n' "$CMDS" | wc -l | tr -d ' ')" "$TESTS" "$MBT" "$DOCS"

# ---------- 1. 文档里提到的子命令必须真存在 ----------
prose=$(ls ./*.md docs/*.md examples/*.md 2>/dev/null)
# 历史记录页按当时的真实情况写，不参与「现在是否还对」的判定。
prose_now=''
for f in $prose; do
  case "$(basename "$f")" in
    CHANGELOG.md|fixes.md|november.md) ;;
    *) prose_now="$prose_now $f" ;;
  esac
done
mentioned=$(
  {
    grep -hoE '\$M [a-z][a-z-]+' $prose
    grep -hoE '\./main [a-z][a-z-]+' $prose
    grep -hoE 'moon run cmd/main -- [a-z][a-z-]+' $prose
    grep -hoE 'moonbit-sat [a-z][a-z-]+' $prose
  } 2>/dev/null | awk '{print $NF}' | sort -u
  printf '%s\n' "$CMDS"
)
unknown=$(printf '%s\n' "$mentioned" | grep -vxF "$CMDS" | grep -vE '^(-|moon|main|build|exe)$' || true)
if [ -n "$unknown" ]; then
  bad "文档提到的子命令源码里没有：$(printf '%s ' $unknown)"
else
  ok "文档提到的每个子命令都在 main.mbt 的分发里"
fi

# ---------- 2. 「当前版本」与 moon.mod ----------
# 含 `moon.mod` 字样的行是「指向单源」的写法，不算写死。
stale=$(
  grep -rnH '当前版本' $prose_now 2>/dev/null \
  | grep -v 'moon\.mod' \
  | while IFS= read -r l; do
      f=${l%%:*}; body=${l#*:}; text=${body#*:}
      v=$(printf '%s' "$text" | grep -oE '0\.[0-9]+\.[0-9]+' | head -1)
      [ -n "$v" ] && [ "$v" != "$VER" ] && printf '%s(%s) ' "$f" "$v"
    done
)
if [ -n "$stale" ]; then
  bad "「当前版本」与 moon.mod（$VER）不符：$stale"
else
  ok "「当前版本」与 moon.mod 一致（$VER）"
fi

# ---------- 2b. 版本区间「0.5.0 → 0.7.N」的右端 ----------
# 这个写法只出现在 README 的索引行，表示「本期到当前版本为止」。
# 其它页面里的历史区间（如 0.7.7 → 0.7.8）是在记录某次改动，不参与判定。
range_bad=$(
  grep -rhoE '0\.5\.0 → 0\.[0-9]+\.[0-9]+' $prose_now 2>/dev/null \
  | grep -oE '0\.[0-9]+\.[0-9]+$' | sort -u | grep -vxF "$VER" || true
)
if [ -n "$range_bad" ]; then
  bad "版本区间写到了 $(printf '%s ' $range_bad)，当前是 $VER"
else
  ok "版本区间右端与 moon.mod 一致"
fi

# ---------- 3. 测试数 ----------
declared=$(
  {
    # 同上：`5/5 passed` 是自检的通过数，不是仓库测试总数
    grep -hoE '[0-9]{2,} passed' $prose_now 2>/dev/null
    grep -hoE '共 [0-9]+ 个测试' $prose_now 2>/dev/null
    # 两位数以上的「NN 个测试」是总数口径；「3 个测试」这种局部计数放行
    grep -hoE '[0-9]{2,} 个测试' $prose_now 2>/dev/null
    grep -hoE 'passed: [0-9]+' $prose_now 2>/dev/null
    grep -hoE '[0-9]+/95\b' $prose_now 2>/dev/null
  } | grep -oE '[0-9]+' | sort -u
)
wrong=$(printf '%s\n' "$declared" | grep -vxF "$TESTS" || true)
if [ -n "$wrong" ]; then
  bad "文档里的测试数 $(printf '%s ' $wrong) 与仓库实际的 $TESTS 不符"
else
  ok "测试数一致（$TESTS）"
fi

# ---------- 4. 文档篇数 ----------
declared=$(
  grep -hoE '共 [0-9]+ 篇|[0-9]+ 篇文档' $prose_now 2>/dev/null | grep -oE '[0-9]+' | sort -u
)
wrong=$(printf '%s\n' "$declared" | grep -vxF "$DOCS" || true)
if [ -n "$wrong" ]; then
  bad "文档里说 docs 有 $(printf '%s ' $wrong) 篇，实际 $DOCS 篇"
else
  ok "docs 篇数一致（$DOCS）"
fi

# ---------- 5. 仓库内 .mbt 文件数 ----------
declared=$(
  grep -hoE '只有 [0-9]+ 个文件|[0-9]+ 个 \.mbt' $prose_now 2>/dev/null | grep -oE '[0-9]+' | sort -u
)
wrong=$(printf '%s\n' "$declared" | grep -vxF "$MBT" || true)
if [ -n "$wrong" ]; then
  bad "文档里说仓库有 $(printf '%s ' $wrong) 个 .mbt，实际 $MBT 个"
else
  ok "仓库 .mbt 文件数一致（$MBT）"
fi

# ---------- 6. 有 FFI 的页面 ----------
ffi=$(grep -rn 'extern "' --include=*.mbt \
      --exclude-dir=.mooncakes --exclude-dir=_build . | wc -l | tr -d ' ')
if [ "$ffi" != "0" ]; then
  bad "仓库里有 $ffi 处 extern \"，纯 MoonBit 的说法要改"
else
  ok "仓库源码 0 处 extern \""
fi

# ---------- 7. 同一件事的两份叙述 ----------
# 只提示，不判错：这几个测量值在 admin 页之外重复出现时，读者可能看到两套
# 不同口径的数。真正需要人看的是「是否注明了机器与口径」。
for n in 295345 113290 3155787 182055 182469 277.5 89.1 112.4 92.3; do
  for f in $prose_now; do
    grep -q "$n" "$f" 2>/dev/null || continue
    case "$f" in
      docs/benchmarks.md|docs/申报书.md) continue ;;
    esac
    grep -q 'benchmarks.md' "$f" || warn "测量值 $n 出现在 $f，而该页没有指向 benchmarks.md 的出处"
  done
done

echo
if [ "$fail" -eq 0 ]; then
  echo "doccheck: 0 problems"
else
  echo "doccheck: $fail problems"
fi
exit $(( fail > 0 ))
