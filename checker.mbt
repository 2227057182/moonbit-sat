///|
/// One step of a DRAT-style proof log.
pub struct DratStep {
  is_delete : Bool
  lits : Array[Lit]
}

///|
/// Parse the textual proof produced by `Proof` into steps.
pub fn parse_drat(text : String) -> Array[DratStep] {
  let steps : Array[DratStep] = []
  for raw in text.split("\n") {
    let line = raw.trim()
    if line.length() == 0 {
      continue
    }
    let is_delete = line[0] == 'd'
    let lits : Array[Lit] = []
    for n in scan_drat_ints(line) {
      if n == 0 {
        continue
      }
      let v = (if n < 0 { -n } else { n }) - 1
      lits.push(lit_new(v, n < 0))
    }
    steps.push({ is_delete : is_delete, lits : lits })
  }
  steps
}

///|
fn scan_drat_ints(line : StringView) -> Array[Int] {
  let out : Array[Int] = []
  let mut acc = 0
  let mut has_digit = false
  let mut neg = false
  for c in line {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      acc = acc * 10 + (code - 48)
      has_digit = true
    } else if code == 45 && !has_digit {
      neg = true
    } else if has_digit {
      out.push(if neg { -acc } else { acc })
      acc = 0
      has_digit = false
      neg = false
    }
  }
  if has_digit {
    out.push(if neg { -acc } else { acc })
  }
  out
}

///|
fn lit_value(assigns : Array[Int], l : Lit) -> Int {
  let v = lit_var(l)
  let a = assigns[v]
  if a < 0 {
    -1
  } else if lit_is_neg(l) {
    1 - a
  } else {
    a
  }
}

///|
/// Reverse unit propagation: assign the negation of `lits`, then run unit
/// propagation over the alive clause pool.  Returns true when a conflict is
/// reached, i.e. `lits` is a RUP consequence of the pool.
fn rup_check(
  pool : Array[Array[Lit]],
  alive : Array[Bool],
  num_vars : Int,
  lits : Array[Lit],
) -> Bool {
  let assigns : Array[Int] = Array::make(num_vars, -1)
  // RUP assumes the negation of the candidate clause: for each literal l
  // in the clause, `not l` becomes true.
  for l in lits {
    let v = lit_var(l)
    assigns[v] = if lit_is_neg(l) {
      1
    } else {
      0
    }
  }
  let mut changed = true
  while changed {
    changed = false
    let mut i = 0
    while i < pool.length() {
      if !alive[i] {
        i = i + 1
        continue
      }
      let c = pool[i]
      let mut sat = false
      let mut unassigned : Lit = -1
      let mut unassigned_count = 0
      for l in c {
        let val = lit_value(assigns, l)
        if val == 1 {
          sat = true
          break
        }
        if val < 0 {
          unassigned = l
          unassigned_count = unassigned_count + 1
        }
      }
      if !sat {
        if unassigned_count == 0 {
          return true
        }
        if unassigned_count == 1 {
          let v = lit_var(unassigned)
          assigns[v] = if lit_is_neg(unassigned) {
            0
          } else {
            1
          }
          changed = true
        }
      }
      i = i + 1
    }
  }
  false
}

///|
fn same_clause(a : Array[Lit], b : Array[Lit]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for l in a {
    let mut found = false
    for m in b {
      if l == m {
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  true
}

///|
fn clause_contains(c : Array[Lit], l : Lit) -> Bool {
  for m in c {
    if m == l {
      return true
    }
  }
  false
}

///|
/// Build the resolvent of the candidate clause and a pool clause on the pivot,
/// and report whether it is a tautology (which is asymmetric-tautological by
/// definition, no propagation needed).
fn make_resolvent(
  candidate : Array[Lit],
  other : Array[Lit],
  pivot : Lit,
) -> (Array[Lit], Bool) {
  let out : Array[Lit] = []
  for l in candidate {
    if l != pivot && !clause_contains(out, l) {
      out.push(l)
    }
  }
  let neg = lit_neg(pivot)
  for l in other {
    if l != neg && !clause_contains(out, l) {
      out.push(l)
    }
  }
  let mut taut = false
  for l in out {
    if clause_contains(out, lit_neg(l)) {
      taut = true
      break
    }
  }
  (out, taut)
}

///|
/// Resolution asymmetric tautology check.  `lits`[0] is the pivot; every alive
/// pool clause holding its negation must yield a resolvent that is RUP.  When
/// the pool contains no clause with the negated pivot the check succeeds
/// vacuously, which is what lets a solver introduce a fresh variable.
fn rat_check(
  pool : Array[Array[Lit]],
  alive : Array[Bool],
  num_vars : Int,
  lits : Array[Lit],
) -> Bool {
  if lits.length() == 0 {
    return false
  }
  let pivot = lits[0]
  let neg = lit_neg(pivot)
  let mut i = 0
  while i < pool.length() {
    if alive[i] && clause_contains(pool[i], neg) {
      let (res, taut) = make_resolvent(lits, pool[i], pivot)
      if !taut && !rup_check(pool, alive, num_vars, res) {
        return false
      }
    }
    i = i + 1
  }
  true
}

///|
/// Shared driver for both checkers.  `allow_rat` turns the fallback on;
/// `require_empty` decides whether the proof has to end with the empty clause.
fn check_steps(
  formula : Formula,
  steps : Array[DratStep],
  allow_rat : Bool,
  require_empty : Bool,
) -> Bool {
  let pool : Array[Array[Lit]] = []
  let alive : Array[Bool] = []
  for c in formula.clauses {
    pool.push(c.lits)
    alive.push(true)
  }
  let mut saw_empty = false
  for step in steps {
    if step.is_delete {
      let mut i = 0
      while i < pool.length() {
        if alive[i] && same_clause(pool[i], step.lits) {
          alive[i] = false
          break
        }
        i = i + 1
      }
    } else {
      if !rup_check(pool, alive, formula.num_vars, step.lits) {
        if !allow_rat || !rat_check(pool, alive, formula.num_vars, step.lits) {
          return false
        }
      }
      pool.push(step.lits)
      alive.push(true)
      if step.lits.length() == 0 {
        saw_empty = true
      }
    }
  }
  if require_empty {
    saw_empty
  } else {
    true
  }
}

///|
/// Verify a DRAT proof against the original formula, accepting RUP only.
/// Every added clause must be a RUP consequence of the current pool, and the
/// proof must end with the empty clause.  Clause deletions are honoured by
/// marking the matched clause dead.  This is the mode the CDCL core produces
/// and the mode the competition-facing claims rest on.
pub fn check_drat(formula : Formula, steps : Array[DratStep]) -> Bool {
  check_steps(formula, steps, false, true)
}

///|
/// Verify a DRAT proof with the full rule set: an added clause is accepted when
/// it is either RUP or RAT on its first literal.  This is what external tools
/// emit when they introduce definitions that are not implied by the formula.
/// Costs one extra propagation pass per resolvent, so it is the slower mode.
pub fn check_drat_rat(formula : Formula, steps : Array[DratStep]) -> Bool {
  check_steps(formula, steps, true, true)
}

///|
/// Convenience wrapper: verify the textual proof for a formula, RUP only.
pub fn verify_proof(formula : Formula, proof_text : String) -> Bool {
  check_drat(formula, parse_drat(proof_text))
}

///|
/// Convenience wrapper: verify the textual proof with the RUP + RAT rule set.
pub fn verify_proof_rat(formula : Formula, proof_text : String) -> Bool {
  check_drat_rat(formula, parse_drat(proof_text))
}
