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
/// Verify a DRAT proof against the original formula.  Every added clause
/// must be a RUP consequence of the current pool, and the proof must end with
/// the empty clause.  Clause deletions are honoured by marking the matched
/// clause dead.  RAT steps are not supported because the CDCL core only emits
/// RUP steps; a non-RUP addition is reported as a failure.
pub fn check_drat(formula : Formula, steps : Array[DratStep]) -> Bool {
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
        return false
      }
      pool.push(step.lits)
      alive.push(true)
      if step.lits.length() == 0 {
        saw_empty = true
      }
    }
  }
  saw_empty
}

///|
/// Convenience wrapper: verify the textual proof for a formula.
pub fn verify_proof(formula : Formula, proof_text : String) -> Bool {
  check_drat(formula, parse_drat(proof_text))
}
