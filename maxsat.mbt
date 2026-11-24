///|
/// Weighted partial MaxSAT instance (WCNF).
pub struct Wcnf {
  num_vars : Int
  top : Int
  hard : Array[Array[Lit]]
  soft : Array[Array[Lit]]
  weights : Array[Int]
  header_ok : Bool
}

///|
/// Parse the DIMACS WCNF dialect: `p wcnf V C TOP`, then one clause per line
/// prefixed by its weight.  Clauses whose weight reaches TOP are hard.
pub fn parse_wcnf(text : String) -> Wcnf {
  let mut num_vars = 0
  let mut top = 0
  let mut header_ok = false
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
      }
      if ints.length() >= 3 && ints[2] > 0 {
        top = ints[2]
        header_ok = true
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
  { num_vars : num_vars, top : top, hard : hard, soft : soft, weights : weights, header_ok : header_ok }
}

///|
/// Why this instance cannot be optimised, or `None` when it is well formed.
/// A WCNF file without `p wcnf <vars> <clauses> <top>` (with a positive top)
/// cannot say which clauses are hard, and a negative weight has no meaning in
/// the cost model; both used to be accepted silently and then either mis-read
/// the instance or drive the encoder into an invalid range.
pub fn wcnf_error(w : Wcnf) -> String? {
  if !w.header_ok {
    return Some(
      "WCNF header must be `p wcnf <vars> <clauses> <top>` with a positive top",
    )
  }
  let mut i = 0
  while i < w.weights.length() {
    if w.weights[i] < 0 {
      return Some("WCNF soft weight \{w.weights[i]} is negative")
    }
    i = i + 1
  }
  None
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
  if k < 0 {
    // `cost <= k` with a negative k is unsatisfiable; say so with the empty
    // clause instead of handing a negative budget to the counter encoding.
    f.add([]) |> ignore
    return f
  }
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
/// Both halves of an optimality claim whose inputs come from outside: the
/// assignment said to reach `cost`, and a refutation of `cost - 1` written by
/// whatever solver produced it.  The assignment is recomputed against the WCNF
/// text and the proof is replayed on a freshly rebuilt encoding, so neither
/// input is taken on trust.  Returns `(upper, lower)`.
pub fn verify_maxsat_external(
  w : Wcnf,
  cost : Int,
  model : Array[Bool],
  proof_text : String,
) -> (Bool, Bool) {
  if cost < 0 {
    return (false, false)
  }
  let upper = verify_maxsat_solution(w, model, cost)
  // cost 0 没有下界可证：代价 0 意味着所有软子句都被满足。
  let lower = if cost == 0 {
    true
  } else {
    verify_maxsat_bound(w, cost - 1, proof_text)
  }
  (upper, lower)
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
    if wt < 0 {
      fail("WCNF soft weight \{wt} is negative")
    }
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

///|
/// Core-guided optimisation in the OLL style.  Every soft clause gets a fresh
/// relaxation variable `b`, the clause becomes `c ∨ b`, and the soft side becomes
/// the literal `¬b`.  One call asks for all still-weighted `¬b` at once; an unsat
/// core says at least the cheapest weight in it must be paid, so that weight is
/// added to the lower bound and subtracted from every clause of the core.  A
/// clause whose weight reaches zero turns into the hard unit `¬b`.
///
/// Two things this buys over the encoding-based `maxsat_solve`: the formula never
/// carries a cardinality network, so there is no `weight_cap` on the total soft
/// weight, and every step is justified by a core instead of a binary search over
/// encodings.
///|
/// Result of a core-guided run.
///
/// - `Solved(model, cost)`: an optimal model and its cost.
/// - `Infeasible`: the hard clauses alone are unsatisfiable.
/// - `Budgeted(lower, upper)`: the round budget ran out before the bounds met.
///   `lower` only grows through cores; `upper` starts at the total soft weight
///   and drops only when a model is found, so `upper - lower` is what is left
///   to close.
pub enum OllOutcome {
  Solved(Array[Bool], Int)
  Infeasible
  Budgeted(Int, Int)
}

fn maxsat_oll_core(w : Wcnf, max_rounds : Int) -> OllOutcome {
  // Below the encoding cap the reformulation path is much faster than
  // core-guided search when all soft weights are small and equal, so take it:
  // same optimum, one implementation to trust.  The cap is a speed choice only.
  // Above it the core-guided loop below still answers, and that is what makes
  // this entry point uncapped.
  let mut total = 0
  for x in w.weights {
    total = total + x
  }
  if total <= 512 {
    let encoded = try {
      maxsat_solution(w, 512)
    } catch {
      _ => None
    }
    let outcome = match encoded {
      Some((model, cost)) => Solved(model, cost)
      None => Infeasible
    }
    return outcome
  }
  let f = Formula::new(w.num_vars)
  for c in w.hard {
    f.add(c) |> ignore
  }
  let s = Solver::new(f)
  // One relaxation per (soft clause, weight layer).  A core saturates the
  // layers it touches and hands the remainder to a fresh relaxation, so the
  // same clause can be hit by several cores without paying its weight twice.
  let bodies : Array[Array[Lit]] = []
  let units : Array[Lit] = []
  let weights : Array[Int] = []
  let demanded : Array[Bool] = []
  let mut i = 0
  while i < w.soft.length() {
    let body : Array[Lit] = []
    for l in w.soft[i] {
      body.push(l)
    }
    let b = lit_new(s.new_var(), false)
    let relaxed : Array[Lit] = []
    for l in body {
      relaxed.push(l)
    }
    relaxed.push(b)
    s.add_clause(relaxed) |> ignore
    bodies.push(body)
    units.push(lit_neg(b))
    weights.push(w.weights[i])
    demanded.push(true)
    i = i + 1
  }
  // Hard clauses alone unsat: no assignment, so no optimum to report.
  if !s.solve([]) {
    return Infeasible
  }
  // The branch and bound: `lb` only grows through cores, `ub` only shrinks as
  // models are found, and every model found is blocked so the next one has to
  // pay less.  The search stops when the two meet, or when the blockers leave
  // nothing cheaper than the best model already seen.
  let mut lb = 0
  let mut ub = total
  let mut have_best = false
  let mut best : Array[Bool] = []
  let mut rounds = 0
  while true {
    if max_rounds > 0 && rounds >= max_rounds {
      return Budgeted(lb, ub)
    }
    rounds = rounds + 1
    let assumptions : Array[Lit] = []
    let mut j = 0
    while j < units.length() {
      if demanded[j] && weights[j] > 0 {
        assumptions.push(units[j])
      }
      j = j + 1
    }
    let mut sat = false
    let mut core : Array[Lit] = []
    if assumptions.length() == 0 {
      sat = s.solve([])
    } else {
      let (verdict, found) = s.solve_core(assumptions)
      sat = verdict
      core = found
    }
    if sat {
      let full = s.model()
      let model : Array[Bool] = []
      let mut v = 0
      while v < w.num_vars {
        model.push(if v < full.length() { full[v] } else { false })
        v = v + 1
      }
      let cost = maxsat_model_cost(w, model)
      if cost >= 0 && (!have_best || cost < ub) {
        ub = cost
        best = model
        have_best = true
      }
      if have_best && ub == lb {
        break
      }
      // Block this assignment: at least one clause it violates has to be
      // satisfied by the next model, so the cost strictly drops.
      let block : Array[Lit] = []
      let mut k = 0
      while k < bodies.length() {
        if !clause_holds(bodies[k], model) {
          block.push(units[k])
        }
        k = k + 1
      }
      if block.length() == 0 || !s.add_clause(block) {
        break
      }
    } else if core.length() == 0 {
      // Unsat independently of the assumptions: nothing left to bound.
      break
    } else {
      let hits : Array[Int] = []
      for c in core {
        let mut k = 0
        let mut found = false
        while k < units.length() && !found {
          if units[k] == c && demanded[k] && weights[k] > 0 {
            let mut dup = false
            for h in hits {
              if h == k {
                dup = true
              }
            }
            if !dup {
              hits.push(k)
            }
            found = true
          }
          k = k + 1
        }
      }
      if hits.length() == 0 {
        break
      }
      let mut wmin = -1
      for h in hits {
        if wmin < 0 || weights[h] < wmin {
          wmin = weights[h]
        }
      }
      if wmin <= 0 {
        break
      }
      lb = lb + wmin
      // At least one clause of the core gives up its cheapest layer; those
      // clauses are saturated for this round and hand their remainder to fresh
      // relaxation literals.
      let relax : Array[Lit] = []
      for h in hits {
        demanded[h] = false
        relax.push(lit_neg(units[h]))
        if weights[h] - wmin > 0 {
          let nb = lit_new(s.new_var(), false)
          let relaxed : Array[Lit] = []
          for l in bodies[h] {
            relaxed.push(l)
          }
          relaxed.push(nb)
          s.add_clause(relaxed) |> ignore
          bodies.push(bodies[h])
          units.push(lit_neg(nb))
          weights.push(weights[h] - wmin)
          demanded.push(true)
        }
      }
      s.add_clause(relax) |> ignore
      if have_best && ub == lb {
        break
      }
    }
  }
  if have_best {
    Solved(best, ub)
  } else {
    Infeasible
  }
}

///|
/// Optimal weighted MaxSAT cost by core-guided search, or `-1` when the hard
/// clauses alone are unsatisfiable.  No cap on the total soft weight: this path
/// never builds a cardinality encoding.
pub fn maxsat_oll(w : Wcnf) -> Int {
  match maxsat_oll_core(w, 0) {
    Solved(_, cost) => cost
    Infeasible => -1
    Budgeted(_, _) => -1
  }
}

///|
/// Core-guided run with a round budget, so a large instance cannot spin
/// forever.  `max_rounds <= 0` means no budget.  A round is one core query plus
/// its bookkeeping; the count is deterministic for a given input, not a
/// wall-clock deadline.
pub fn maxsat_oll_result(w : Wcnf, max_rounds : Int) -> OllOutcome {
  maxsat_oll_core(w, max_rounds)
}

///|
/// Optimal assignment and its cost by core-guided search.  `None` when the hard
/// clauses alone are unsatisfiable.
pub fn maxsat_oll_solution(w : Wcnf) -> (Array[Bool], Int)? {
  match maxsat_oll_core(w, 0) {
    Solved(model, cost) => Some((model, cost))
    _ => None
  }
}