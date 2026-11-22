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
/// Sinz sequential-counter encoding of `sum(xs) <= k`, written into a formula.
/// Variables are handed out from `start` in a fixed order and the first free
/// index afterwards is returned, so the same arguments always yield the same
/// formula — proofs about this encoding can be replayed later.
fn add_at_most_k_formula(
  f : Formula,
  xs : Array[Lit],
  k : Int,
  start : Int,
) -> Int {
  let n = xs.length()
  let mut next = start
  if k >= n {
    return next
  }
  if k == 0 {
    for x in xs {
      f.add([lit_neg(x)]) |> ignore
    }
    return next
  }
  let rows = n - 1
  let s_vars : Array[Array[Lit]] = []
  let mut i = 0
  while i < rows {
    let row : Array[Lit] = []
    let mut j = 0
    while j < k {
      row.push(lit_new(next, false))
      next = next + 1
      j = j + 1
    }
    s_vars.push(row)
    i = i + 1
  }
  f.add([lit_neg(xs[0]), s_vars[0][0]]) |> ignore
  let mut i = 1
  while i < rows {
    f.add([lit_neg(xs[i]), s_vars[i][0]]) |> ignore
    f.add([lit_neg(s_vars[i - 1][0]), s_vars[i][0]]) |> ignore
    let mut j = 1
    while j < k {
      f.add([
        lit_neg(xs[i]),
        lit_neg(s_vars[i - 1][j - 1]),
        s_vars[i][j],
      ]) |> ignore
      f.add([lit_neg(s_vars[i - 1][j]), s_vars[i][j]]) |> ignore
      j = j + 1
    }
    f.add([lit_neg(xs[i]), lit_neg(s_vars[i - 1][k - 1])]) |> ignore
    i = i + 1
  }
  f.add([lit_neg(xs[n - 1]), lit_neg(s_vars[rows - 1][k - 1])]) |> ignore
  next
}

///|
/// Build the cardinality-extended CNF that decides whether the soft-clause
/// cost can stay within `k`: an enumeration of partial MaxSAT as a single SAT
/// instance.  The construction is deterministic, which is what makes an
/// exported lower-bound proof checkable against a freshly rebuilt encoding.
pub fn maxsat_encoding(w : Wcnf, k : Int) -> Formula {
  let f = Formula::new(w.num_vars)
  for c in w.hard {
    f.add(c) |> ignore
  }
  let mut next = w.num_vars
  let relaxed : Array[Lit] = []
  let mut i = 0
  while i < w.soft.length() {
    let r = lit_new(next, false)
    next = next + 1
    let lits : Array[Lit] = []
    for l in w.soft[i] {
      lits.push(l)
    }
    lits.push(r)
    f.add(lits) |> ignore
    let mut t = 0
    while t < w.weights[i] {
      relaxed.push(r)
      t = t + 1
    }
    i = i + 1
  }
  let end = add_at_most_k_formula(f, relaxed, k, next)
  if end > f.num_vars {
    f.num_vars = end
  }
  f
}

///|
/// A lower bound on the optimal cost taken from one unsat core: the soft
/// clauses in the core cannot all hold at once, so at least the cheapest of
/// them is violated.  Returns `0` when every soft clause can be satisfied
/// simultaneously, and `-1` when the hard clauses alone are unsatisfiable.
pub fn maxsat_core_bound(w : Wcnf) -> Int {
  let f = Formula::new(w.num_vars)
  for c in w.hard {
    f.add(c) |> ignore
  }
  let s = Solver::new(f)
  let selectors : Array[Lit] = []
  let mut i = 0
  while i < w.soft.length() {
    let r = lit_new(s.new_var(), false)
    let lits : Array[Lit] = []
    for l in w.soft[i] {
      lits.push(l)
    }
    lits.push(lit_neg(r))
    s.add_clause(lits) |> ignore
    selectors.push(r)
    i = i + 1
  }
  let assumptions : Array[Lit] = []
  for r in selectors {
    assumptions.push(r)
  }
  let (sat, core) = s.solve_core(assumptions)
  if sat {
    return 0
  }
  if core.length() == 0 {
    return -1
  }
  let mut best = -1
  for c in core {
    let mut idx = 0
    while idx < selectors.length() {
      if selectors[idx] == c {
        let wt = w.weights[idx]
        if best < 0 || wt < best {
          best = wt
        }
        break
      }
      idx = idx + 1
    }
  }
  best
}

///|
/// Is there an assignment with total soft-clause cost `<= k`?
fn maxsat_feasible(w : Wcnf, k : Int) -> Bool {
  let s = Solver::new(maxsat_encoding(w, k))
  s.solve([])
}

///|
/// A DRAT proof that no assignment keeps the soft cost within `k`, or `None`
/// when such an assignment exists.  The proof is stated over the extended CNF
/// from `maxsat_encoding`, so it can be replayed without trusting the solver
/// run that produced it.
pub fn maxsat_bound_proof(w : Wcnf, k : Int) -> String? {
  let s = Solver::new(maxsat_encoding(w, k))
  let p = s.enable_proof()
  if s.solve([]) {
    None
  } else {
    Some(p.text())
  }
}

///|
/// Check a lower-bound proof: rebuild the encoding for the same `k` and replay
/// the DRAT steps against it.  A `true` answer means the proof really does
/// establish that cost `k` is unreachable.
pub fn verify_maxsat_bound(w : Wcnf, k : Int, proof_text : String) -> Bool {
  verify_proof(maxsat_encoding(w, k), proof_text)
}

///|
/// Does one clause hold under the assignment?  Missing variables are read as
/// false, which is the only reading that cannot manufacture a satisfied clause.
fn clause_holds(c : Array[Lit], model : Array[Bool]) -> Bool {
  for l in c {
    let v = lit_var(l)
    let value = if v < model.length() { model[v] } else { false }
    if lit_is_neg(l) {
      if !value {
        return true
      }
    } else if value {
      return true
    }
  }
  false
}

///|
/// Cost of an assignment: the sum of weights of violated soft clauses, or `-1`
/// when some hard clause fails.  The cost is recomputed from the assignment,
/// never taken from the search loop that produced it.
pub fn maxsat_model_cost(w : Wcnf, model : Array[Bool]) -> Int {
  for c in w.hard {
    if !clause_holds(c, model) {
      return -1
    }
  }
  let mut cost = 0
  let mut i = 0
  while i < w.soft.length() {
    if !clause_holds(w.soft[i], model) {
      cost = cost + w.weights[i]
    }
    i = i + 1
  }
  cost
}

///|
/// Check an optimal assignment the same way a third party would: the model must
/// satisfy every hard clause, and the recomputed soft cost must equal the
/// claimed optimum.  This is the upper half of an optimality claim.
pub fn verify_maxsat_solution(
  w : Wcnf,
  model : Array[Bool],
  claimed_cost : Int,
) -> Bool {
  let cost = maxsat_model_cost(w, model)
  if cost < 0 {
    return false
  }
  cost == claimed_cost
}

///|
/// An assignment reaching the optimum and the cost it actually pays.  `None`
/// when the hard clauses alone are unsatisfiable.
pub fn maxsat_solution(w : Wcnf, weight_cap : Int) -> (Array[Bool], Int)? raise {
  let opt = maxsat_solve(w, weight_cap)
  if opt < 0 {
    return None
  }
  let s = Solver::new(maxsat_encoding(w, opt))
  if !s.solve([]) {
    return None
  }
  let full = s.model()
  let model : Array[Bool] = []
  let mut i = 0
  while i < w.num_vars {
    model.push(if i < full.length() { full[i] } else { false })
    i = i + 1
  }
  Some((model, opt))
}

///|
/// Same as `maxsat_solution`, but never raises: an exceeded weight cap is
/// reported as `None` instead of an error, so a first call needs no `try`.
pub fn maxsat_model(w : Wcnf, weight_cap : Int) -> (Array[Bool], Int)? {
  try {
    maxsat_solution(w, weight_cap)
  } catch {
    _ => None
  }
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
  // 一个 unsat core 给出下界：core 里至少有一条软子句必然被违反，所以最优
  // 代价不会低于该 core 中最便宜的权重。用它抬高二分的下端点。
  let core_lower = maxsat_core_bound(w)
  let mut lo = if core_lower > 1 { core_lower } else { 1 }
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
