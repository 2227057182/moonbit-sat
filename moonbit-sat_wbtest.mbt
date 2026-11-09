///|
/// Exhaustive truth-table check used as the reference oracle for small
/// formulas.
fn brute_sat(f : Formula) -> Bool {
  let n = f.num_vars
  if n > 12 {
    abort("brute force limited to 12 variables")
  }
  let total = 1 << n
  let mut a = 0
  while a < total {
    let mut ok = true
    for c in f.clauses {
      let mut sat = false
      for l in c.lits {
        let v = lit_var(l)
        let bit = (a >> v) & 1
        let val = if lit_is_neg(l) {
          bit == 0
        } else {
          bit == 1
        }
        if val {
          sat = true
          break
        }
      }
      if !sat {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
    a = a + 1
  }
  false
}

///|
/// Deterministic tiny LCG so tests are reproducible on every backend.
fn lcg(s : Int) -> Int {
  (s * 31 + 17) % 1000003
}

///|
/// Check that the reported model satisfies every clause.
fn model_satisfies(f : Formula, model : Array[Bool]) -> Bool {
  for c in f.clauses {
    let mut sat = false
    for l in c.lits {
      let v = lit_var(l)
      let val = if lit_is_neg(l) {
        !model[v]
      } else {
        model[v]
      }
      if val {
        sat = true
        break
      }
    }
    if !sat {
      return false
    }
  }
  true
}

///|
test "literal encoding round trip" {
  let mut v = 0
  while v < 20 {
    let pos = lit_new(v, false)
    let neg = lit_new(v, true)
    assert_eq(lit_var(pos), v)
    assert_eq(lit_var(neg), v)
    assert_false(lit_is_neg(pos))
    assert_true(lit_is_neg(neg))
    assert_eq(lit_neg(pos), neg)
    assert_eq(lit_neg(neg), pos)
    v = v + 1
  }
}

///|
test "dimacs parse and render round trip" {
  let text = "c sample\np cnf 3 2\n1 -2 0\n2 3 0\n"
  let f = parse_dimacs(text)
  assert_eq(f.num_vars, 3)
  assert_eq(f.num_clauses(), 2)
  let out = to_dimacs(f)
  let f2 = parse_dimacs(out)
  assert_eq(f2.num_vars, 3)
  assert_eq(f2.num_clauses(), 2)
}

///|
test "trivial sat cases" {
  let f = Formula::new(1)
  f.add([lit_new(0, false), lit_new(0, true)]) |> ignore
  let s = Solver::new(f)
  assert_true(s.solve([]))
  let g = Formula::new(1)
  g.add([lit_new(0, false)]) |> ignore
  g.add([lit_new(0, true)]) |> ignore
  let s2 = Solver::new(g)
  assert_false(s2.solve([]))
  let h = Formula::new(2)
  h.add([]) |> ignore
  let s3 = Solver::new(h)
  assert_false(s3.solve([]))
}

///|
test "unit propagation chain" {
  let f = Formula::new(3)
  f.add([lit_new(0, false)]) |> ignore
  f.add([lit_new(0, true), lit_new(1, false)]) |> ignore
  f.add([lit_new(1, true), lit_new(2, false)]) |> ignore
  f.add([lit_new(2, true)]) |> ignore
  let s = Solver::new(f)
  assert_false(s.solve([]))
}

///|
test "cdcl agrees with brute force" {
  let mut seed = 12345
  let mut round = 0
  while round < 80 {
    seed = lcg(seed)
    let n = 3 + seed % 3
    seed = lcg(seed)
    let m = 4 + seed % 6
    let f = Formula::new(n)
    let mut j = 0
    while j < m {
      seed = lcg(seed)
      let len = 1 + seed % 3
      let lits : Array[Lit] = []
      let mut k = 0
      while k < len {
        seed = lcg(seed)
        let v = seed % n
        let neg = (seed / 7) % 2 == 1
        lits.push(lit_new(v, neg))
        k = k + 1
      }
      f.add(lits) |> ignore
      j = j + 1
    }
    let s = Solver::new(f)
    let result = s.solve([])
    let expected = brute_sat(f)
    assert_eq(result, expected)
    if result {
      assert_true(model_satisfies(f, s.model()))
    }
    round = round + 1
  }
}

///|
test "assumptions are respected" {
  let f = Formula::new(2)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  let s = Solver::new(f)
  assert_true(s.solve([]))
  assert_false(s.solve([lit_new(0, true), lit_new(1, true)]))
  assert_true(s.solve([lit_new(0, true)]))
}

///|
test "incremental clause addition" {
  let f = Formula::new(2)
  f.add([lit_new(0, false)]) |> ignore
  let s = Solver::new(f)
  assert_true(s.solve([]))
  assert_true(s.add_clause([lit_new(0, true), lit_new(1, false)]))
  assert_true(s.solve([]))
  assert_false(s.add_clause([lit_new(1, true)]))
  assert_false(s.solve([]))
}

///|
test "proof log records learnt clauses and final empty clause" {
  let f = Formula::new(1)
  f.add([lit_new(0, false)]) |> ignore
  f.add([lit_new(0, true)]) |> ignore
  let s = Solver::new(f)
  let p = s.enable_proof()
  assert_false(s.solve([]))
  let text = p.text()
  assert_true(text.length() > 0)
  assert_true(text.has_suffix("0\n"))
}

///|
///|
test "drat proof verifies on unsat instance" {
  let f = Formula::new(2)
  f.add([lit_new(0, false)]) |> ignore
  f.add([lit_new(1, false)]) |> ignore
  f.add([lit_new(0, true), lit_new(1, true)]) |> ignore
  let s = Solver::new(f)
  let p = s.enable_proof()
  assert_false(s.solve([]))
  assert_true(verify_proof(f, p.text()))
}

///|
test "checker rejects non-rup steps and missing empty clause" {
  let f = Formula::new(1)
  f.add([lit_new(0, false)]) |> ignore
  assert_false(verify_proof(f, "-1 0\n0\n"))
  assert_false(verify_proof(f, "1 0\n"))
}

///|
test "drat proof verifies on random unsat formulas" {
  let mut seed = 777
  let mut round = 0
  let mut checked = 0
  while round < 40 {
    seed = lcg(seed)
    let n = 3 + seed % 3
    seed = lcg(seed)
    let m = 3 + seed % 4
    let f = Formula::new(n)
    let mut j = 0
    while j < m {
      seed = lcg(seed)
      let len = 1 + seed % 3
      let lits : Array[Lit] = []
      let mut k = 0
      while k < len {
        seed = lcg(seed)
        lits.push(lit_new(seed % n, (seed / 7) % 2 == 1))
        k = k + 1
      }
      f.add(lits) |> ignore
      j = j + 1
    }
    let s = Solver::new(f)
    let p = s.enable_proof()
    if !s.solve([]) && !brute_sat(f) {
      assert_true(verify_proof(f, p.text()))
      checked = checked + 1
    }
    round = round + 1
  }
  assert_true(checked > 0)
}

///|
fn clause_sat_bits(c : Array[Lit], a : Int) -> Bool {
  for l in c {
    let v = lit_var(l)
    let bit = (a >> v) & 1
    let val = if lit_is_neg(l) {
      bit == 0
    } else {
      bit == 1
    }
    if val {
      return true
    }
  }
  false
}

///|
fn brute_maxsat(w : Wcnf) -> Int {
  let n = w.num_vars
  let total = 1 << n
  let mut best = -1
  let mut a = 0
  while a < total {
    let mut ok = true
    for c in w.hard {
      if !clause_sat_bits(c, a) {
        ok = false
        break
      }
    }
    if ok {
      let mut cost = 0
      let mut i = 0
      while i < w.soft.length() {
        if !clause_sat_bits(w.soft[i], a) {
          cost = cost + w.weights[i]
        }
        i = i + 1
      }
      if best < 0 || cost < best {
        best = cost
      }
    }
    a = a + 1
  }
  best
}

///|
test "wcnf parse and optimal cost" {
  let text = "p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n"
  let w = parse_wcnf(text)
  assert_eq(w.num_vars, 2)
  assert_eq(w.top, 10)
  assert_eq(w.hard.length(), 1)
  assert_eq(w.soft.length(), 2)
  assert_eq(w.hard.length(), 1)
  assert_eq(w.soft.length(), 2)
  assert_eq(w.weights[0], 1)
  assert_false(maxsat_feasible(w, 0))
  assert_true(maxsat_feasible(w, 1))
  assert_eq(maxsat_solve(w, 100), 1)
}

///|
test "maxsat agrees with brute force" {
  let mut seed = 4242
  let mut round = 0
  while round < 40 {
    seed = lcg(seed)
    let n = 3 + seed % 2
    seed = lcg(seed)
    let soft_count = 2 + seed % 3
    let w = Wcnf::{
      num_vars : n,
      top : 100,
      hard : [],
      soft : [],
      weights : [],
    }
    seed = lcg(seed)
    let hl = 1 + seed % 2
    let lits : Array[Lit] = []
    let mut k = 0
    while k < hl {
      seed = lcg(seed)
      lits.push(lit_new(seed % n, (seed / 7) % 2 == 1))
      k = k + 1
    }
    w.hard.push(lits)
    let mut i = 0
    while i < soft_count {
      seed = lcg(seed)
      let len = 1 + seed % 2
      let slits : Array[Lit] = []
      let mut j = 0
      while j < len {
        seed = lcg(seed)
        slits.push(lit_new(seed % n, (seed / 7) % 2 == 1))
        j = j + 1
      }
      seed = lcg(seed)
      w.soft.push(slits)
      w.weights.push(1 + seed % 3)
      i = i + 1
    }
    let expected = brute_maxsat(w)
    if expected >= 0 {
      assert_eq(maxsat_solve(w, 200), expected)
    }
    round = round + 1
  }
}
