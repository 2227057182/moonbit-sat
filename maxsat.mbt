///|
/// Weighted partial MaxSAT instance (WCNF).
pub struct Wcnf {
  num_vars : Int
  top : Int
  hard : Array[Array[Lit]]
  soft : Array[Array[Lit]]
  weights : Array[Int]
}

///|
/// Parse the DIMACS WCNF dialect: `p wcnf V C TOP`, then one clause per line
/// prefixed by its weight.  Clauses whose weight reaches TOP are hard.
pub fn parse_wcnf(text : String) -> Wcnf {
  let mut num_vars = 0
  let mut top = 0
  let hard : Array[Array[Lit]] = []
  let soft : Array[Array[Lit]] = []
  let weights : Array[Int] = []
  for raw in text.split("\n") {
    let line = raw.trim()
    if line.length() == 0 {
      continue
    }
    if line[0] == 'c' {
      continue
    }
    if line[0] == 'p' {
      let ints = scan_ints(line)
      if ints.length() >= 2 {
        num_vars = ints[0]
        top = if ints.length() >= 3 { ints[2] } else { ints[1] }
      }
      continue
    }
    let ints = scan_ints(line)
    if ints.length() < 2 {
      continue
    }
    let weight = ints[0]
    let lits : Array[Lit] = []
    let mut k = 1
    while k < ints.length() {
      if ints[k] == 0 {
        break
      }
      let v = (if ints[k] < 0 { -ints[k] } else { ints[k] }) - 1
      if v >= num_vars {
        num_vars = v + 1
      }
      lits.push(lit_new(v, ints[k] < 0))
      k = k + 1
    }
    if weight >= top {
      hard.push(lits)
    } else {
      soft.push(lits)
      weights.push(weight)
    }
  }
  { num_vars : num_vars, top : top, hard : hard, soft : soft, weights : weights }
}

///|
/// Sinz sequential-counter encoding of `sum(xs) <= k`.  The `xs` array may
/// repeat the same literal to express a weight.
fn add_at_most_k(s : Solver, xs : Array[Lit], k : Int) -> Unit {
  let n = xs.length()
  if k >= n {
    return
  }
  if k == 0 {
    for x in xs {
      s.add_clause([lit_neg(x)]) |> ignore
    }
    return
  }
  let rows = n - 1
  let s_vars : Array[Array[Lit]] = []
  let mut i = 0
  while i < rows {
    let row : Array[Lit] = []
    let mut j = 0
    while j < k {
      row.push(lit_new(s.new_var(), false))
      j = j + 1
    }
    s_vars.push(row)
    i = i + 1
  }
  s.add_clause([lit_neg(xs[0]), s_vars[0][0]]) |> ignore
  let mut i = 1
  while i < rows {
    s.add_clause([lit_neg(xs[i]), s_vars[i][0]]) |> ignore
    s.add_clause([lit_neg(s_vars[i - 1][0]), s_vars[i][0]]) |> ignore
    let mut j = 1
    while j < k {
      s.add_clause([
        lit_neg(xs[i]),
        lit_neg(s_vars[i - 1][j - 1]),
        s_vars[i][j],
      ]) |> ignore
      s.add_clause([lit_neg(s_vars[i - 1][j]), s_vars[i][j]]) |> ignore
      j = j + 1
    }
    s.add_clause([lit_neg(xs[i]), lit_neg(s_vars[i - 1][k - 1])]) |> ignore
    i = i + 1
  }
  s.add_clause([lit_neg(xs[n - 1]), lit_neg(s_vars[rows - 1][k - 1])]) |> ignore
}

///|
/// Is there an assignment with total soft-clause cost `<= k`?
fn maxsat_feasible(w : Wcnf, k : Int) -> Bool {
  let f = Formula::new(w.num_vars)
  for c in w.hard {
    f.add(c) |> ignore
  }
  let s = Solver::new(f)
  let relaxed : Array[Lit] = []
  let mut i = 0
  while i < w.soft.length() {
    let r = lit_new(s.new_var(), false)
    let lits : Array[Lit] = []
    for l in w.soft[i] {
      lits.push(l)
    }
    lits.push(r)
    s.add_clause(lits) |> ignore
    let mut t = 0
    while t < w.weights[i] {
      relaxed.push(r)
      t = t + 1
    }
    i = i + 1
  }
  add_at_most_k(s, relaxed, k)
  s.solve([])
}

///|
/// Optimal weighted MaxSAT cost, or `-1` when the hard clauses alone are
/// unsatisfiable.  Weight totalling is capped so the cardinality encoding
/// stays small; the cap is reported rather than silently ignored.
pub fn maxsat_solve(w : Wcnf, weight_cap : Int) -> Int raise {
  let mut total = 0
  for wt in w.weights {
    total = total + wt
  }
  if total > weight_cap {
    fail("total soft weight \{total} exceeds the encoding cap \{weight_cap}")
  }
  if !maxsat_feasible(w, total) {
    return -1
  }
  if maxsat_feasible(w, 0) {
    return 0
  }
  let mut lo = 1
  let mut hi = total
  while lo < hi {
    let mid = (lo + hi) / 2
    if maxsat_feasible(w, mid) {
      hi = mid
    } else {
      lo = mid + 1
    }
  }
  lo
}
