///|
test "unsat core covers the conflicting assumptions" {
  // (x0 ∨ x1) ∧ (¬x0 ∨ ¬x1): satisfiable on its own, contradictory once both
  // x0 and x1 are assumed true.
  let f = Formula::new(2)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  f.add([lit_new(0, true), lit_new(1, true)]) |> ignore
  let s = Solver::new(f)
  let (sat, core) = s.solve_core([lit_new(0, false), lit_new(1, false)])
  assert_false(sat)
  assert_true(core.length() == 2)
  assert_false(s.solve(core))
}

///|
test "unsat core drops assumptions that are not involved" {
  let f = Formula::new(3)
  f.add([lit_new(0, true), lit_new(1, true)]) |> ignore
  let s = Solver::new(f)
  let (sat, core) = s.solve_core([
    lit_new(0, false),
    lit_new(1, false),
    lit_new(2, false),
  ])
  assert_false(sat)
  assert_true(core.length() >= 2)
  let mut unrelated = false
  for l in core {
    if lit_var(l) == 2 {
      unrelated = true
    }
  }
  assert_false(unrelated)
  assert_false(s.solve(core))
}

///|
test "satisfiable query yields an empty core" {
  let f = Formula::new(2)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  let s = Solver::new(f)
  let (sat, core) = s.solve_core([lit_new(0, false)])
  assert_true(sat)
  assert_true(core.length() == 0)
}

///|
test "unsat without assumptions yields an empty core" {
  let f = Formula::new(1)
  f.add([lit_new(0, false)]) |> ignore
  f.add([lit_new(0, true)]) |> ignore
  let s = Solver::new(f)
  let (sat, core) = s.solve_core([])
  assert_false(sat)
  assert_true(core.length() == 0)
}

///|
test "every reported core is a valid subset on a fixed 3-CNF" {
  // (x0 ∨ x1) ∧ (¬x0 ∨ x2) ∧ (¬x1 ∨ ¬x2)
  let f = Formula::new(3)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  f.add([lit_new(0, true), lit_new(2, false)]) |> ignore
  f.add([lit_new(1, true), lit_new(2, true)]) |> ignore
  let s = Solver::new(f)
  let mut mask = 0
  while mask < 8 {
    let assumptions : Array[Lit] = []
    let mut v = 0
    while v < 3 {
      if ((mask >> v) & 1) == 1 {
        assumptions.push(lit_new(v, false))
      }
      v = v + 1
    }
    let (sat, core) = s.solve_core(assumptions)
    if !sat && core.length() > 0 {
      // core 必须是 assumptions 的子集
      for l in core {
        let mut is_member = false
        for a in assumptions {
          if a == l {
            is_member = true
          }
        }
        assert_true(is_member)
      }
      // 只用 core 里的假设，仍然必须不可满足
      assert_false(s.solve(core))
    }
    mask = mask + 1
  }
}
