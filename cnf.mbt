///|
/// A single clause.  `lits` is a flat literal array; the two watched
/// positions are stored inside the clause so propagation never allocates.
pub struct Clause {
  lits : Array[Lit]
  mut learnt : Bool
  mut activity : Double
  mut lbd : Int
  mut watch0 : Int
  mut watch1 : Int
  mut dead : Bool
}

///|
pub fn Clause::new(lits : Array[Lit], learnt : Bool) -> Clause {
  let w1 = if lits.length() > 1 {
    1
  } else {
    0
  }
  {
    lits : lits,
    learnt : learnt,
    activity : 0.0,
    lbd : 0,
    watch0 : 0,
    watch1 : w1,
    dead : false,
  }
}

///|
pub fn Clause::size(self : Clause) -> Int {
  self.lits.length()
}

///|
pub fn Clause::mark_dead(self : Clause) -> Unit {
  self.dead = true
}

///|
pub fn Clause::set_learnt(self : Clause, v : Bool) -> Unit {
  self.learnt = v
}

///|
pub fn Clause::add_activity(self : Clause, v : Double) -> Unit {
  self.activity = self.activity + v
}

///|
pub fn Clause::set_lbd(self : Clause, v : Int) -> Unit {
  self.lbd = v
}

///|
/// Move one of the two watched positions.  `which` is 0 or 1.
pub fn Clause::move_watch(self : Clause, which : Int, pos : Int) -> Unit {
  if which == 0 {
    self.watch0 = pos
  } else {
    self.watch1 = pos
  }
}

///|
pub fn Clause::watch_at(self : Clause, which : Int) -> Int {
  if which == 0 {
    self.watch0
  } else {
    self.watch1
  }
}

///|
/// A CNF formula.  Variables are 0-based internally; DIMACS input and
/// output use the usual 1-based numbering.
pub struct Formula {
  mut num_vars : Int
  clauses : Array[Clause]
}

///|
pub fn Formula::new(num_vars : Int) -> Formula {
  { num_vars : num_vars, clauses : [] }
}

///|
/// Append a clause.  Returns `false` when the clause is empty, i.e. the
/// formula is trivially unsatisfiable.
pub fn Formula::add(self : Formula, lits : Array[Lit]) -> Bool {
  self.clauses.push(Clause::new(lits, false))
  lits.length() > 0
}

///|
pub fn Formula::num_clauses(self : Formula) -> Int {
  self.clauses.length()
}

///|
/// Scan an integer list out of one DIMACS line.  `p` and `cnf` tokens are
/// skipped naturally because they are not digits.
fn scan_ints(line : StringView) -> Array[Int] {
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
/// Parse DIMACS CNF text.
pub fn parse_dimacs(text : String) -> Formula raise {
  let mut num_vars = 0
  let mut formula = Formula::new(0)
  let mut pending : Array[Lit] = []
  for raw in text.split("\n") {
    let line = raw.trim()
    if line.length() == 0 {
      continue
    }
    let first = line[0]
    if first == 'c' {
      continue
    }
    if first == 'p' {
      let ints = scan_ints(line)
      if ints.length() >= 1 {
        num_vars = ints[0]
        formula = Formula::new(num_vars)
      }
      continue
    }
    for n in scan_ints(line) {
      if n == 0 {
        let lits = pending
        pending = []
        formula.add(lits) |> ignore
      } else {
        let v = (if n < 0 { -n } else { n }) - 1
        if v < 0 {
          fail("DIMACS literal 0 must only terminate a clause")
        }
        if v >= formula.num_vars {
          formula.num_vars = v + 1
        }
        pending.push(lit_new(v, n < 0))
      }
    }
  }
  if pending.length() > 0 {
    formula.add(pending) |> ignore
  }
  formula
}

///|
/// Render the formula as DIMACS text (1-based variable numbers).
pub fn to_dimacs(formula : Formula) -> String {
  let buf = StringBuilder()
  buf.write_string("p cnf \{formula.num_vars} \{formula.clauses.length()}\n")
  for c in formula.clauses {
    for l in c.lits {
      let v = lit_var(l) + 1
      if lit_is_neg(l) {
        buf.write_string("-\{v} ")
      } else {
        buf.write_string("\{v} ")
      }
    }
    buf.write_string("0\n")
  }
  buf.to_string()
}

///|
/// Deduplicate the literals of one clause and report whether the clause is a
/// tautology, i.e. it contains both `l` and `-l`.  Such clauses can never
/// constrain a model, so dropping them is sound and shrinks every later
/// propagation pass.
fn clause_normalize(lits : Array[Lit], num_vars : Int) -> (Array[Lit], Bool) {
  let state : Array[Int] = Array::make(num_vars, 0)
  let out : Array[Lit] = []
  let mut taut = false
  for l in lits {
    let v = lit_var(l)
    let sign = if lit_is_neg(l) {
      2
    } else {
      1
    }
    if v >= 0 && v < num_vars {
      if state[v] == sign {
        continue
      }
      if state[v] != 0 {
        taut = true
        continue
      }
      state[v] = sign
    }
    out.push(l)
  }
  (out, taut)
}

///|
/// Normalise the formula before handing it to `Solver::new`: repeated literals
/// inside a clause are collapsed and tautological clauses are removed.  The
/// solver caches clause shape in its watch lists, so this must run on the
/// `Formula`, not on a live solver.  Returns the number of clauses dropped.
pub fn Formula::simplify(self : Formula) -> Int {
  let nv = self.num_vars
  let kept : Array[Clause] = []
  let mut removed = 0
  for c in self.clauses {
    let (lits, taut) = clause_normalize(c.lits, nv)
    if taut {
      removed = removed + 1
    } else {
      kept.push(Clause::new(lits, c.learnt))
    }
  }
  self.clauses.clear()
  for c in kept {
    self.clauses.push(c)
  }
  removed
}

///|
/// Number of tautological clauses currently in the formula.  Reading this is
/// cheap and lets a caller warn about redundant input without rewriting it.
pub fn Formula::num_tautologies(self : Formula) -> Int {
  let nv = self.num_vars
  let mut n = 0
  for c in self.clauses {
    let (_, taut) = clause_normalize(c.lits, nv)
    if taut {
      n = n + 1
    }
  }
  n
}
