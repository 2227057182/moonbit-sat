#!/usr/bin/env python3
"""Generate a random 3-SAT instance in DIMACS.

usage: gen3sat.py <vars> <ratio> <seed> <out.cnf>
Clauses = round(ratio * vars); literals picked without repetition inside a
clause, signs randomised. No dedup / tautology removal: the point is to match
the usual random-formula distribution, not to make the instance pretty.
"""
import random
import sys


def gen(n, ratio, seed, path):
    rnd = random.Random(seed)
    m = max(1, round(ratio * n))
    with open(path, "w", encoding="utf-8") as f:
        f.write("p cnf %d %d\n" % (n, m))
        for _ in range(m):
            vs = rnd.sample(range(1, n + 1), 3)
            f.write("%d %d %d 0\n" % tuple(v if rnd.random() < 0.5 else -v for v in vs))


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit("usage: gen3sat.py <vars> <ratio> <seed> <out.cnf>")
    gen(int(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3]), sys.argv[4])
