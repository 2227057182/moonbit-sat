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
    // 注释与统计行（`c`、`s`、`o` 开头）不是证明步骤。真实 DRAT 文件带 `c`
    // 注释，本仓库的命令行也会在证明后打印 `s` 与一行 `c …` 统计；把它们
    // 当子句解析，那些数字就变成了字面，检查器会与公式对不上。
    let head = line[0]
    if !(head == 'd' || head == '-' || (head >= '0' && head <= '9')) {
      continue
    }
    let is_delete = head == 'd'
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
fn lit_index(l : Lit) -> Int {
  2 * (l / 2) + (if l % 2 == 1 { 1 } else { 0 })
}

///|
/// Two-watched-literal propagator owned by the checker.  It is written
/// independently of `solver.mbt` on purpose: the checker has to re-derive each
/// step with code the solver does not share, so a solver bug cannot hide a bad
/// proof.  Watchers survive between checks; only the trail is rolled back.
///
/// Storage is flat on purpose.  A pool of ~300k clauses is visited once per
/// watched literal during propagation, and an array-of-arrays turns each visit
/// into a pointer chase; keeping every literal in one `Array[Lit]` and the
/// clause boundaries in `begin`/`len` keeps the hot loop on contiguous memory.
/// `len[ci] == 0` means the clause was deleted, so no separate `alive` array is
/// needed.
priv struct CheckDb {
  lits : Array[Lit]
  begin : Array[Int]
  len : Array[Int]
  watches : Array[Array[Int]]
  values : Array[Int]
  trail : Array[Lit]
  mut qhead : Int
  mut num_vars : Int
  mut base_len : Int
  mut inconsistent : Bool
  buckets : Array[Array[Int]]
}

///|
/// Order-independent hash over a clause's literals, used to find the pool entry
/// a deletion step refers to without scanning the whole pool.
fn clause_hash(lits : Array[Lit]) -> Int {
  let mut h = lits.length() * 7
  for l in lits {
    h = (h + lit_index(l)) % 8192
  }
  h
}

///|
fn CheckDb::new(num_vars : Int) -> CheckDb {
  let watches : Array[Array[Int]] = []
  let mut i = 0
  while i < 2 * num_vars {
    watches.push([])
    i = i + 1
  }
  let buckets : Array[Array[Int]] = []
  let mut b = 0
  while b < 8192 {
    buckets.push([])
    b = b + 1
  }
  {
    begin : [],
    buckets : buckets,
    inconsistent : false,
    len : [],
    lits : [],
    num_vars : num_vars,
    watches : watches,
    values : Array::make(num_vars, -1),
    trail : [],
    qhead : 0,
    base_len : 0,
  }
}

///|
fn CheckDb::ensure(self : CheckDb, v : Int) -> Unit {
  while self.num_vars <= v {
    self.watches.push([])
    self.watches.push([])
    self.values.push(-1)
    self.num_vars = self.num_vars + 1
  }
}

///|
/// Value of a literal under the current trail: 1 true, 0 false, -1 unassigned.
/// Kept as plain arithmetic rather than going through `lit_is_neg` because this
/// is the innermost call of propagation.
fn CheckDb::value(self : CheckDb, l : Lit) -> Int {
  let v = l / 2
  if v >= self.values.length() {
    return -1
  }
  let a = self.values[v]
  if a < 0 {
    -1
  } else if l % 2 == 1 {
    1 - a
  } else {
    a
  }
}

///|
/// Assign `l` true.  Returns false when that contradicts an existing value,
/// which is itself a conflict for the caller.
fn CheckDb::assign(self : CheckDb, l : Lit) -> Bool {
  let v = l / 2
  let val = if l % 2 == 1 { 0 } else { 1 }
  let cur = self.values[v]
  if cur >= 0 {
    return cur == val
  }
  self.values[v] = val
  self.trail.push(l)
  true
}

///|
/// Roll the trail back to the base layer.  Unit clauses are permanent facts
/// about the pool, so they form a base layer that assumptions can never evict;
/// only the tentative part of the trail is undone.  Watchers are left alone:
/// they only record which two literals a clause is watching, which does not
/// depend on any temporary assumption.
fn CheckDb::reset(self : CheckDb) -> Unit {
  let mut i = self.trail.length()
  while i > self.base_len {
    let l = self.trail[i - 1]
    self.values[l / 2] = -1
    self.trail.pop() |> ignore
    i = i - 1
  }
  self.qhead = 0
}

///|
fn CheckDb::attach(self : CheckDb, ci : Int) -> Unit {
  let base = self.begin[ci]
  if self.len[ci] >= 2 {
    self.watches[lit_index(self.lits[base])].push(ci)
    self.watches[lit_index(self.lits[base + 1])].push(ci)
  }
}

///|
fn CheckDb::add(self : CheckDb, lits : Array[Lit]) -> Unit {
  for l in lits {
    self.ensure(l / 2)
  }
  let ci = self.begin.length()
  self.begin.push(self.lits.length())
  self.len.push(lits.length())
  for l in lits {
    self.lits.push(l)
  }
  self.buckets[clause_hash(lits)].push(ci)
  self.attach(ci)
  if lits.length() == 1 {
    if self.assign(lits[0]) {
      self.base_len = self.trail.length()
    } else {
      self.inconsistent = true
    }
  }
}

///|
/// Whether pool clause `ci` holds `l`.  Deleted clauses hold nothing.
fn CheckDb::flat_contains(self : CheckDb, ci : Int, l : Lit) -> Bool {
  if self.len[ci] == 0 {
    return false
  }
  let base = self.begin[ci]
  let stop = base + self.len[ci]
  let mut i = base
  while i < stop {
    if self.lits[i] == l {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Copy a pool clause out of the flat store.  Only the RAT fallback path needs
/// this; it is never touched by the RUP hot loop.
fn CheckDb::to_array(self : CheckDb, ci : Int) -> Array[Lit] {
  let out : Array[Lit] = []
  let base = self.begin[ci]
  let stop = base + self.len[ci]
  let mut i = base
  while i < stop {
    out.push(self.lits[i])
    i = i + 1
  }
  out
}

///|
/// Whether the pool clause at `ci` is the multiset given by `lits`.
fn CheckDb::flat_same(self : CheckDb, ci : Int, lits : Array[Lit]) -> Bool {
  if self.len[ci] != lits.length() {
    return false
  }
  for l in lits {
    if !self.flat_contains(ci, l) {
      return false
    }
  }
  true
}

///|
/// Mark the pool clause matching a deletion step as dead.  Only the hash bucket
/// is visited, not the whole pool.  A dead clause is dropped from the watcher
/// list the next time propagation walks over it (`len == 0` entries are skipped
/// without being written back).
fn CheckDb::mark_dead(self : CheckDb, lits : Array[Lit]) -> Unit {
  let b = self.buckets[clause_hash(lits)]
  let mut i = 0
  while i < b.length() {
    let ci = b[i]
    if self.len[ci] != 0 && self.flat_same(ci, lits) {
      self.len[ci] = 0
      return
    }
    i = i + 1
  }
}

///|
/// Propagate to a fixpoint.  Returns false on conflict.
fn CheckDb::propagate(self : CheckDb) -> Bool {
  let mut conflict = false
  while self.qhead < self.trail.length() && !conflict {
    let p = self.trail[self.qhead]
    self.qhead = self.qhead + 1
    let target = lit_neg(p)
    let ws = self.watches[lit_index(target)]
    let mut w = 0
    let mut i = 0
    while i < ws.length() && !conflict {
      let ci = ws[i]
      i = i + 1
      if self.len[ci] == 0 {
        continue
      }
      let base = self.begin[ci]
      if self.lits[base] == target {
        let a0 = self.lits[base]
        self.lits[base] = self.lits[base + 1]
        self.lits[base + 1] = a0
      }
      if self.lits[base + 1] != target {
        ws[w] = ci
        w = w + 1
        continue
      }
      let first = self.lits[base]
      if self.value(first) == 1 {
        ws[w] = ci
        w = w + 1
        continue
      }
      let mut moved = false
      let mut k = 2
      let clen = self.len[ci]
      while k < clen && !moved {
        let lk = self.lits[base + k]
        if self.value(lk) != 0 {
          let tmp = self.lits[base + 1]
          self.lits[base + 1] = lk
          self.lits[base + k] = tmp
          self.watches[lit_index(lk)].push(ci)
          moved = true
        }
        k = k + 1
      }
      if !moved {
        ws[w] = ci
        w = w + 1
        if self.value(first) == 0 {
          conflict = true
        } else {
          self.assign(first) |> ignore
        }
      }
    }
    while i < ws.length() {
      ws[w] = ws[i]
      w = w + 1
      i = i + 1
    }
    while ws.length() > w {
      ws.pop() |> ignore
    }
  }
  !conflict
}

///|
/// Reverse unit propagation: assign the negation of `lits`, then propagate over
/// the pool.  Returns true when a conflict is reached, i.e. `lits` is a RUP
/// consequence of the pool.
fn rup_check(db : CheckDb, lits : Array[Lit]) -> Bool {
  if db.inconsistent {
    return true
  }
  db.reset()
  let mut consistent = true
  for l in lits {
    if !db.assign(lit_neg(l)) {
      consistent = false
      break
    }
  }
  if !consistent {
    db.reset()
    return true
  }
  let no_conflict = db.propagate()
  db.reset()
  !no_conflict
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
fn rat_check(db : CheckDb, lits : Array[Lit]) -> Bool {
  if lits.length() == 0 {
    return false
  }
  let pivot = lits[0]
  let neg = lit_neg(pivot)
  let mut i = 0
  while i < db.len.length() {
    if db.len[i] != 0 && db.flat_contains(i, neg) {
      let (res, taut) = make_resolvent(lits, db.to_array(i), pivot)
      if !taut && !rup_check(db, res) {
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
  let db = CheckDb::new(formula.num_vars)
  for c in formula.clauses {
    db.add(c.lits)
  }
  let mut saw_empty = false
  for step in steps {
    if step.is_delete {
      db.mark_dead(step.lits)
    } else {
      if !rup_check(db, step.lits) {
        if !allow_rat || !rat_check(db, step.lits) {
          return false
        }
      }
      db.add(step.lits)
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
