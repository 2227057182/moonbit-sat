///|
/// Edge cases that the main suite does not exercise: empty inputs, degenerate
/// clauses, tautologies and repeated calls on one solver instance.
test "empty formula parses and solves as satisfiable" {
  let f = parse_dimacs("p cnf 0 0\n")
  assert_eq(f.num_vars, 0)
  assert_eq(f.num_clauses(), 0)
  assert_true(Solver::new(f).solve([]))
}

///|
test "a bare terminator line is the empty clause" {
  let f = parse_dimacs("p cnf 1 1\n0\n")
  assert_eq(f.num_clauses(), 1)
  assert_false(Solver::new(f).solve([]))
}

///|
test "simplify collapses repeated literals" {
  let f = parse_dimacs("p cnf 2 1\n1 1 2 0\n")
  assert_eq(f.clauses[0].size(), 3)
  assert_eq(f.simplify(), 0)
  assert_eq(f.clauses[0].size(), 2)
  assert_true(Solver::new(f).solve([]))
}

///|
test "simplify drops tautological clauses" {
  let f = parse_dimacs("p cnf 2 2\n1 -1 0\n1 2 0\n")
  assert_eq(f.num_tautologies(), 1)
  assert_eq(f.simplify(), 1)
  assert_eq(f.num_clauses(), 1)
  assert_true(Solver::new(f).solve([]))
}

///|
test "a formula made only of tautologies is trivially satisfiable" {
  let f = parse_dimacs("p cnf 2 1\n1 -1 2 -2 0\n")
  assert_eq(f.simplify(), 1)
  assert_eq(f.num_clauses(), 0)
  assert_true(Solver::new(f).solve([]))
}

///|
test "simplify keeps the answer on random formulas" {
  let mut seed = 99
  let mut round = 0
  while round < 30 {
    seed = lcg(seed)
    let n = 3 + seed % 3
    let f = Formula::new(n)
    let mut j = 0
    while j < 6 {
      seed = lcg(seed)
      let len = 1 + seed % 3
      let lits : Array[Lit] = []
      let mut k = 0
      while k < len {
        seed = lcg(seed)
        lits.push(lit_new(seed % n, seed % 2 == 1))
        k = k + 1
      }
      f.add(lits) |> ignore
      j = j + 1
    }
    let copy = Formula::new(n)
    for c in f.clauses {
      let lits : Array[Lit] = []
      for l in c.lits {
        lits.push(l)
      }
      copy.add(lits) |> ignore
    }
    copy.simplify() |> ignore
    assert_eq(Solver::new(f).solve([]), Solver::new(copy).solve([]))
    round = round + 1
  }
}

///|
test "dimacs parser grows the declared variable count" {
  let f = parse_dimacs("p cnf 1 1\n3 0\n")
  assert_eq(f.num_vars, 3)
  assert_true(Solver::new(f).solve([]))
}

///|
test "proof deletion lines are rendered in drat syntax" {
  let p = Proof::new()
  p.add([lit_new(0, false), lit_new(1, true)])
  p.delete([lit_new(0, false)])
  p.empty()
  let t = p.text()
  assert_true(t.contains("d 1 0\n"))
  assert_true(t.contains("0\n"))
}

///|
test "unsatisfiable assumptions do not poison the next call" {
  let f = Formula::new(1)
  f.add([lit_new(0, false)]) |> ignore
  let s = Solver::new(f)
  assert_false(s.solve([lit_new(0, true)]))
  assert_true(s.solve([]))
}

///|
test "maxsat reports -1 when hard clauses conflict" {
  let w = parse_wcnf("p wcnf 2 2 5\n5 1 0\n5 -1 0\n")
  assert_eq(maxsat_solve(w, 100), -1)
}

///|
test "maxsat handles an instance without soft clauses" {
  let w = parse_wcnf("p wcnf 2 1 10\n10 1 2 0\n")
  assert_eq(w.soft.length(), 0)
  assert_eq(maxsat_solve(w, 100), 0)
}
