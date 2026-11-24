#!/usr/bin/env python3
"""Check that a model satisfies a DIMACS CNF, independently of any solver.

usage: check_model.py <file.cnf> <"v ... 0" line>
Exit 0 when every clause has a true literal; exit 1 with the offending clause.
A variable the model line omits counts as unassigned, and an unassigned literal
cannot satisfy a clause -- callers are expected to print a total model.
"""
import sys


def parse_cnf(path):
    cls = []
    for line in open(path, encoding="utf-8"):
        s = line.strip()
        if not s or s[0] in "cp%0":
            continue
        lits = [int(x) for x in s.split() if x != "0"]
        if lits:
            cls.append(lits)
    return cls


def parse_model(vline):
    if vline.lstrip().startswith("v"):
        vline = vline.lstrip()[1:]
    model = {}
    for tok in vline.split():
        lit = int(tok)
        if lit:
            model[abs(lit)] = lit > 0
    return model


def lit_true(lit, model):
    val = model.get(abs(lit))
    if val is None:
        return False
    return val if lit > 0 else not val


def main():
    cls = parse_cnf(sys.argv[1])
    model = parse_model(sys.argv[2])
    for i, c in enumerate(cls, 1):
        if not any(lit_true(l, model) for l in c):
            print("clause %d unsatisfied: %s" % (i, c))
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
