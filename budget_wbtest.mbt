///|
/// Pigeonhole formula: `pigeons` pigeons into `holes` holes, with variable
/// P(i, h) = i * holes + h.  Unsatisfiable whenever pigeons > holes, and no
/// CDCL search can conclude that without producing conflicts first.
fn pigeonhole(pigeons : Int, holes : Int) -> Formula {
  let f = Formula::new(pigeons * holes)
  let mut i = 0
  while i < pigeons {
    let lits : Array[Lit] = []
    let mut h = 0
    while h < holes {
      lits.push(lit_new(i * holes + h, false))
      h = h + 1
    }
    f.add(lits) |> ignore
    i = i + 1
  }
  i = 0
  while i < pigeons {
    let mut a = 0
    while a < holes {
      let mut b = a + 1
      while b < holes {
        f.add([lit_new(i * holes + a, true), lit_new(i * holes + b, true)]) |> ignore
        b = b + 1
      }
      a = a + 1
    }
    i = i + 1
  }
  let mut a = 0
  while a < pigeons {
    let mut b = a + 1
    while b < pigeons {
      let mut h = 0
      while h < holes {
        f.add([lit_new(a * holes + h, true), lit_new(b * holes + h, true)]) |> ignore
        h = h + 1
      }
      b = b + 1
    }
    a = a + 1
  }
  f
}

///|
fn outcome_is_unknown(o : SolveOutcome) -> Bool {
  match o {
    Unknown => true
    _ => false
  }
}

///|
fn outcome_is_satisfiable(o : SolveOutcome) -> Bool {
  match o {
    Satisfiable => true
    _ => false
  }
}

///|
test "zero budget stops a search that needs conflicts" {
  let s = Solver::new(pigeonhole(4, 3))
  assert_true(outcome_is_unknown(s.solve_with_budget([], 0)))
}

///|
test "a stopped solver keeps its state and still concludes" {
  let s = Solver::new(pigeonhole(4, 3))
  assert_true(outcome_is_unknown(s.solve_with_budget([], 0)))
  assert_false(s.solve([]))
}

///|
test "budget does not change a formula that needs no conflict" {
  let f = Formula::new(2)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  let s = Solver::new(f)
  assert_true(outcome_is_satisfiable(s.solve_with_budget([], 0)))
}
