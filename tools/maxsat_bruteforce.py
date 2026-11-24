#!/usr/bin/env python3
"""Compare the weighted MaxSAT optimum reported by `maxsat` against brute force.

`maxsat-verify` checks that our own `o` line and our own proof agree with each
other, and `maxsat-verify-external` checks somebody else's answer against our
checker. Neither of them asks the only question a reviewer really cares about:
is the number itself the true minimum? This script answers it from first
principles, for instances small enough to enumerate.

For every instance it writes a WCNF file, runs `maxsat @file`, takes the last
`o <cost>` line, and compares it with the minimum over all 2^n assignments.
Hard clauses are forced to be jointly satisfiable by construction, so a
feasible assignment always exists.

Requires python3 and a built solver; nothing else.

usage: tools/maxsat_bruteforce.py --main PATH [--work DIR]
"""

import argparse
import os
import random
import subprocess
import sys

# n variables, soft clauses, hard clauses, how many instances
TIERS = [
    (8, 24, 0, 100),
    (10, 30, 4, 100),
    (12, 36, 6, 100),
    (12, 34, 20, 50),
    (14, 42, 8, 40),
    (16, 48, 0, 10),
]
WEIGHTS = [1, 2, 3, 5]


def gen_instance(n, n_soft, n_hard, seed):
    """Random WCNF; hard clauses are built to be jointly satisfiable."""
    rng = random.Random(seed)
    witness = rng.getrandbits(n)

    clauses = []
    # hard: pick 1..3 literals, flip the polarity of one so `witness` satisfies it
    for _ in range(n_hard):
        k = rng.randint(1, 3)
        lits = rng.sample(range(n), k)
        signs = [rng.randint(0, 1) for _ in lits]
        pos = rng.randrange(k)
        signs[pos] = 0 if (witness >> lits[pos]) & 1 else 1  # 0 = positive literal
        clauses.append(("hard", None, [(l, s) for l, s in zip(lits, signs)]))
    # soft: random polarity, small weights so the total stays modest
    for _ in range(n_soft):
        k = rng.randint(1, 3)
        lits = rng.sample(range(n), k)
        w = rng.choice(WEIGHTS)
        clauses.append(("soft", w, [(l, rng.randint(0, 1)) for l in lits]))

    top = sum(w for kind, w, _ in clauses if kind == "soft") + 1
    return clauses, top


def write_wcnf(path, n, clauses, top):
    with open(path, "w") as f:
        f.write("p wcnf %d %d %d\n" % (n, len(clauses), top))
        for kind, w, lits in clauses:
            weight = top if kind == "hard" else w
            body = " ".join(("%d" if s == 0 else "-%d") % (l + 1) for l, s in lits)
            f.write("%d %s 0\n" % (weight, body))


def brute_force(n, clauses):
    """True minimum soft cost over all assignments, hard clauses respected."""
    hard, soft = [], []
    for kind, w, lits in clauses:
        pos = neg = 0
        for l, s in lits:
            if s == 0:
                pos |= 1 << l
            else:
                neg |= 1 << l
        (hard if kind == "hard" else soft).append((pos, neg, w or 0))
    best = None
    for a in range(1 << n):
        ok = True
        for pos, neg, _ in hard:
            if not (((~a) & pos) | (a & neg)):
                ok = False
                break
        if not ok:
            continue
        cost = 0
        for pos, neg, w in soft:
            if not (((~a) & pos) | (a & neg)):
                cost += w
        if best is None or cost < best:
            best = cost
    return best


def run_solver(main, path):
    out = subprocess.run([main, "maxsat", "@" + path], capture_output=True, text=True)
    if out.returncode != 0:
        return None, out.stdout + out.stderr
    costs = [ln for ln in out.stdout.splitlines() if ln.startswith("o ")]
    if not costs:
        return None, out.stdout
    return int(costs[-1].split()[1]), out.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--main", required=True, help="path to the built main executable")
    ap.add_argument("--work", default="_build/maxsat-bruteforce")
    args = ap.parse_args()

    os.makedirs(args.work, exist_ok=True)
    print("n,soft,hard,instances,optimal_agree,mismatch,solver_error")
    tot = agree = bad = err = 0
    for n, n_soft, n_hard, cnt in TIERS:
        a = b = e = 0
        for i in range(1, cnt + 1):
            tot += 1
            clauses, top = gen_instance(n, n_soft, n_hard, seed=1000 * n + i)
            path = os.path.join(args.work, "n%d-s%d.wcnf" % (n, i))
            write_wcnf(path, n, clauses, top)
            truth = brute_force(n, clauses)
            ours, log = run_solver(args.main, path)
            if ours is None:
                e += 1
                print("SOLVER-ERROR %s\n%s" % (path, log.strip()[:400]), file=sys.stderr)
            elif ours == truth:
                a += 1
            else:
                b += 1
                print("MISMATCH %s brute=%s ours=%s" % (path, truth, ours), file=sys.stderr)
        print("%d,%d,%d,%d,%d,%d,%d" % (n, n_soft, n_hard, cnt, a, b, e))
        agree += a
        bad += b
        err += e

    print("TOTAL,%d,%d,%d,%d" % (tot, agree, bad, err))
    if bad or err:
        print("FAIL: %d mismatch, %d solver errors" % (bad, err), file=sys.stderr)
        return 1
    print("OK: %d/%d optima equal to brute force" % (agree, tot))
    return 0


if __name__ == "__main__":
    sys.exit(main())
