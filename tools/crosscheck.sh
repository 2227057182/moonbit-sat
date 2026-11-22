#!/usr/bin/env bash
# Cross-check the DRAT proofs this project emits against two C checkers that
# share no code with it: drat-trim (Marijn Heule) and lrat-check (same author,
# separate implementation).  If our own checker has a bug, this catches it;
# if drat-trim and lrat-check disagree, the script fails.
#
#   bash tools/crosscheck.sh              # build the checkers, run every case
#   M=/path/to/main.exe bash tools/crosscheck.sh
#
# Requires: curl, gcc (or cc), python3, a native build of this project.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WS=$(cd "$HERE/.." && pwd)
WORK=${WORK:-$WS/_build/crosscheck}
M=${M:-$WS/_build/native/release/build/cmd/main/main.exe}

say() { printf '%s\n' "$*" >&2; }
die() { say "error: $*"; exit 1; }

[ -x "$M" ] || die "no CLI at $M - run: moon build --target native --release"
command -v gcc >/dev/null || die "gcc is required to build the checkers"
mkdir -p "$WORK"

# --- fetch and build the two checkers -------------------------------------
fetch() { # url out
  if [ ! -s "$2" ]; then
    curl -sSL -o "$2" "$1" || die "download failed: $1"
  fi
}
fetch https://raw.githubusercontent.com/marijnheule/drat-trim/master/drat-trim.c "$WORK/drat-trim.c"
fetch https://raw.githubusercontent.com/marijnheule/drat-trim/master/lrat-check.c "$WORK/lrat-check.c"
gcc -O2 -o "$WORK/drat-trim" "$WORK/drat-trim.c" 2>/dev/null
gcc -O2 -o "$WORK/lrat-check" "$WORK/lrat-check.c" 2>/dev/null
DRAT="$WORK/drat-trim"
LRAT="$WORK/lrat-check"

# --- instance generator ---------------------------------------------------
# Pigeonhole: k pigeons into k-1 holes, unsatisfiable by counting.
gen_php() {
  python3 - "$1" <<'EOF'
import sys
k = int(sys.argv[1]); h = k - 1
def v(p, q): return p * h + q + 1
cl = [[v(p, q) for q in range(h)] for p in range(k)]
for q in range(h):
    for p in range(k):
        for pp in range(p + 1, k):
            cl.append([-v(p, q), -v(pp, q)])
print("p cnf %d %d" % (k * h, len(cl)))
for c in cl:
    print(" ".join(map(str, c)) + " 0")
EOF
}

# The CLI takes formulas inline, so join the file into one argument.
inline() { tr '\n' ';' <"$1"; }

# --- one case -------------------------------------------------------------
# args: label cnf-file proof-file
run_case() {
  local label=$1 cnf=$2 proof=$3
  local stem=${cnf%.cnf}
  local t0 t1 t2 t3 verdict_drat verdict_lrat
  t0=$(date +%s%N)
  "$DRAT" "$cnf" "$proof" -L "$stem.lrat" >"$stem.drat.log" 2>&1 || true
  t1=$(date +%s%N)
  verdict_drat=$(grep -o 's VERIFIED' "$stem.drat.log" || echo 's NOT-VERIFIED')
  t2=$(date +%s%N)
  "$LRAT" "$cnf" "$stem.lrat" >"$stem.lrat.log" 2>&1 || true
  t3=$(date +%s%N)
  if grep -q 'c VERIFIED' "$stem.lrat.log"; then
    verdict_lrat='c VERIFIED'
  else
    verdict_lrat='NOT-VERIFIED'
  fi
  local lines; lines=$(wc -l <"$proof")
  printf '%-14s %6s  %-12s %-13s drat=%5sms lrat=%5sms\n' \
    "$label" "$lines" "$verdict_drat" "$verdict_lrat" \
    "$(( (t1 - t0) / 1000000 ))" "$(( (t3 - t2) / 1000000 ))"
  [ "$verdict_drat" = 's VERIFIED' ] && [ "$verdict_lrat" = 'c VERIFIED' ] || return 1
}

fails=0
printf '%-14s %6s  %-12s %-13s %s\n' case lemmas drat-trim lrat-check time

# --- A. plain UNSAT proofs (pigeonhole) ------------------------------------
for k in 3 4 5 6 7 8 9; do
  cnf="$WORK/php-$k.cnf"; proof="$WORK/php-$k.drat"
  gen_php "$k" >"$cnf"
  "$M" proof "$(inline "$cnf")" | grep -E '^(-?[0-9]|d )' >"$proof"
  run_case "php $k/$(($k - 1))" "$cnf" "$proof" || fails=$((fails + 1))
  rm -f "$cnf" "$proof"
done

# --- B. MaxSAT optimality: the refutation of cost <= opt-1 ------------------
# Each row is "instance:k", where k = opt - 1.
for row in petersen-mwvc.wcnf:5 grid-mwvc.wcnf:9 scheduling.wcnf:0; do
  inst=${row%:*}; k=${row#*:}
  cnf="$WORK/${inst%.wcnf}-k$k.cnf"; proof="$WORK/${inst%.wcnf}-k$k.drat"
  "$M" maxsat-cnf "$(inline "$WS/examples/$inst")" "$k" >"$cnf"
  "$M" maxsat-proof "$(inline "$WS/examples/$inst")" "$k" | grep -E '^(-?[0-9]|d )' >"$proof"
  run_case "${inst%.wcnf} k=$k" "$cnf" "$proof" || fails=$((fails + 1))
  rm -f "$cnf" "$proof"
done

# --- C. large instances (opt in with BIG=1; the k=10 solve alone takes ~4 min) ---
if [ "${BIG:-0}" = "1" ]; then
  gen_php 10 >"$WORK/php-10.cnf"
  "$M" proof "$(inline "$WORK/php-10.cnf")" | grep -E '^(-?[0-9]|d )' >"$WORK/php-10.drat"
  run_case "php 10/9" "$WORK/php-10.cnf" "$WORK/php-10.drat" || fails=$((fails + 1))
  rm -f "$WORK/php-10.cnf" "$WORK/php-10.drat"

  # 20x20 grid MWVC, refute cost <= 199.  The encoding blows up to 80201 vars.
  "$M" grid-wcnf 20 20 >"$WORK/grid20.wcnf"
  "$M" maxsat-cnf "$(inline "$WORK/grid20.wcnf")" 199 >"$WORK/grid20-k199.cnf"
  "$M" maxsat-proof "$(inline "$WORK/grid20.wcnf")" 199 | grep -E '^(-?[0-9]|d )' >"$WORK/grid20-k199.drat"
  run_case "grid20 k=199" "$WORK/grid20-k199.cnf" "$WORK/grid20-k199.drat" || fails=$((fails + 1))
  rm -f "$WORK/grid20.wcnf" "$WORK/grid20-k199.cnf" "$WORK/grid20-k199.drat" "$WORK/grid20-k199.lrat"
fi
if [ "$fails" -ne 0 ]; then
  say "$fails case(s) did not verify"
  exit 1
fi
say "all cases verified by drat-trim and lrat-check"
