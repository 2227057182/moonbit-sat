#!/bin/sh
# 自测：故意把三处口径改错，确认 doccheck 能抓出来。抓不到说明脚本没在工作。
#
#   bash tools/doccheck_selftest.sh
#
# 在临时副本里跑，不碰当前工作区。

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 只复制脚本需要读到的东西：源码、moon.mod、文档。
mkdir -p "$TMP/docs" "$TMP/examples" "$TMP/cmd/main" "$TMP/tools"
cp "$ROOT/moon.mod" "$TMP/" 2>/dev/null
cp "$ROOT"/*.md "$TMP/" 2>/dev/null
cp "$ROOT"/docs/*.md "$TMP/docs/" 2>/dev/null
cp "$ROOT"/examples/*.md "$TMP/examples/" 2>/dev/null
cp "$ROOT"/cmd/main/main.mbt "$TMP/cmd/main/" 2>/dev/null
cp "$ROOT"/tools/doccheck.sh "$TMP/tools/" 2>/dev/null
cp "$ROOT"/*.mbt "$TMP/" 2>/dev/null
( cd "$TMP" && git init -q . && git add -A > /dev/null 2>&1 )

fail=0
case_run() {
  name=$1; expect=$2; shift 2
  out=$( cd "$TMP" && bash tools/doccheck.sh 2>&1 )
  if printf '%s' "$out" | grep -qE "$expect"; then
    printf 'ok    %s\n' "$name"
  else
    printf 'BAD   自测失败：%s 没有被抓到\n' "$name"; fail=$((fail + 1))
  fi
  # 每轮把副本还原，避免上一轮的改动影响下一轮
  ( cd "$ROOT" && cp -f *.md "$TMP/" 2>/dev/null; cp -f docs/*.md "$TMP/docs/"; cp -f moon.mod "$TMP/" )
}

printf '自测：把三处口径改错，看 doccheck 是否分别报出\n\n'

# 1. 版本号：把 moon.mod 往前挪一格，文档里的「当前版本」就对不上了
sed -i 's/^version = .*/version = "0.0.1"/' "$TMP/moon.mod"
case_run "版本号不匹配" 'BAD.*当前版本'

# 2. 命令名：把源码里的分发删掉一个，文档里对它的引用就该报错
sed -i 's/cmd == "grid-wcnf"/cmd == "grid-wcnfx"/' "$TMP/cmd/main/main.mbt"
case_run "文档提到源码里没有的子命令" 'BAD.*子命令'

# 3. 测试数：删掉一个测试声明，文档里的 95 就该报错
first=$(grep -rl '^test "' "$TMP"/*.mbt 2>/dev/null | head -1)
if [ -n "$first" ]; then
  sed -i '0,/^test "/{/^test "/d}' "$first"
  case_run "测试数与仓库不符" 'BAD.*测试数'
else
  printf 'skip  副本里没找到测试声明\n'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
  echo "selftest: 3/3 caught"
else
  echo "selftest: $fail missed"
fi
exit $(( fail > 0 ))
