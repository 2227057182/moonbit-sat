#!/usr/bin/env bash
# Difference-test this solver's SAT/UNSAT verdicts against CaDiCaL on random
# 3-SAT, and check that both sides agree on the witness:
#   SAT   -> our model must satisfy every clause (checked by tools/check_model.py)
#   UNSAT -> our DRAT must be accepted by drat-trim, for the first PROOF_SAMPLE
#            instances of each tier (full checking is too slow to do everywhere)
#
# Nothing here touches the solver: it is an outside verdict source, not a test
# of our own checker. Requires cadical and drat-trim on PATH (or set CADICAL /
# DRATTRIM), plus python3.
#
# usage: tools/difftest.sh            # default tiers, 1400 instances
#        TIERS="40:4.26:300" tools/difftest.sh
#        CAP=60 PROOF_SAMPLE=20 tools/difftest.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MAIN=${MAIN:-$ROOT/_build/native/release/build/cmd/main/main.exe}
CADICAL=${CADICAL:-cadical}
DRATTRIM=${DRATTRIM:-drat-trim}
WORK=${WORK:-$ROOT/_build/difftest}
CAP=${CAP:-20}
PROOF_SAMPLE=${PROOF_SAMPLE:-10}
TIERS=${TIERS:-"20:4.26:200 30:4.26:200 40:4.26:200 50:4.26:200 60:4.26:200 20:5.00:100 30:5.00:100 40:5.00:100 80:4.26:50 100:4.26:50"}

for bin in "$MAIN" "$DRATTRIM"; do
  [ -x "$bin" ] || { echo "missing executable: $bin" >&2; exit 2; }
done
command -v "$CADICAL" >/dev/null 2>&1 || { echo "cadical not found (set CADICAL)" >&2; exit 2; }

mkdir -p "$WORK/disagree"
echo "vars,ratio,instances,sat,unsat,agree,disagree,timeout,bad_model,bad_proof,proofs_checked"

T=0; TS=0; TU=0; TA=0; TD=0; TT=0; TM=0; TP=0; PCHK=0
for tier in $TIERS; do
  IFS=':' read -r n ratio cnt <<< "$tier"
  sat=0; unsat=0; agree=0; disagree=0; tmo=0; mbad=0; pbad=0; pchk=0
  for i in $(seq 1 "$cnt"); do
    f="$WORK/n${n}-r${ratio}-s${i}.cnf"
    python3 "$ROOT/tools/gen3sat.py" "$n" "$ratio" "$i" "$f"
    out=$(timeout "$CAP" "$MAIN" solve "@$f" 2>/dev/null); rc=$?
    if [ "$rc" -ne 0 ]; then tmo=$((tmo+1)); continue; fi
    ours=$(printf '%s\n' "$out" | grep -m1 '^s ' | awk '{print $2}')
    cad=$(timeout "$CAP" "$CADICAL" "$f" 2>/dev/null | grep -m1 '^s ' | awk '{print $2}')
    if [ "$ours" = "$cad" ]; then
      agree=$((agree+1))
    else
      disagree=$((disagree+1))
      cp "$f" "$WORK/disagree/" 2>/dev/null || true
      echo "DISAGREE $f ours=$ours cadical=$cad" >&2
    fi
    case "$ours" in
      SATISFIABLE)
        sat=$((sat+1))
        vline=$(printf '%s\n' "$out" | grep -m1 '^v ')
        if ! python3 "$ROOT/tools/check_model.py" "$f" "$vline" >/dev/null; then
          mbad=$((mbad+1)); echo "BAD-MODEL $f" >&2
        fi ;;
      UNSATISFIABLE)
        unsat=$((unsat+1))
        if [ "$pchk" -lt "$PROOF_SAMPLE" ]; then
          drat="$WORK/n${n}-r${ratio}-s${i}.drat"
          "$MAIN" proof "@$f" 2>/dev/null | grep -E '^[0-9d-]' > "$drat"
          if "$DRATTRIM" "$f" "$drat" 2>/dev/null | grep -q 's VERIFIED'; then
            pchk=$((pchk+1))
          else
            pbad=$((pbad+1)); echo "BAD-PROOF $f" >&2
          fi
        fi ;;
    esac
  done
  echo "$n,$ratio,$cnt,$sat,$unsat,$agree,$disagree,$tmo,$mbad,$pbad,$pchk"
  T=$((T+cnt)); TS=$((TS+sat)); TU=$((TU+unsat)); TA=$((TA+agree))
  TD=$((TD+disagree)); TT=$((TT+tmo)); TM=$((TM+mbad)); TP=$((TP+pbad)); PCHK=$((PCHK+pchk))
done

echo "TOTAL,$T,$TS,$TU,$TA,$TD,$TT,$TM,$TP,$PCHK"
if [ "$TD" -ne 0 ] || [ "$TM" -ne 0 ] || [ "$TP" -ne 0 ]; then
  echo "FAIL: disagreements or bad witnesses present (see $WORK/disagree)" >&2
  exit 1
fi
echo "OK: $TA/$T agreed, $TS SAT models checked, $PCHK UNSAT proofs accepted by drat-trim"
