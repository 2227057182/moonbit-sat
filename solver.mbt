///|
/// DRAT-style proof recorder.  Every learnt clause is logged in the order the
/// solver derives it; deletions are logged when the clause database is
/// reduced.  A final `0` line is appended when the solver proves UNSAT.
pub struct Proof {
  lines : Array[String]
}

///|
pub fn Proof::new() -> Proof {
  { lines : [] }
}

///|
pub fn Proof::add(self : Proof, lits : Array[Lit]) -> Unit {
  let buf = StringBuilder()
  for l in lits {
    let v = lit_var(l) + 1
    if lit_is_neg(l) {
      buf.write_string("-\{v} ")
    } else {
      buf.write_string("\{v} ")
    }
  }
  buf.write_string("0\n")
  self.lines.push(buf.to_string())
}

///|
pub fn Proof::delete(self : Proof, lits : Array[Lit]) -> Unit {
  let buf = StringBuilder()
  buf.write_string("d ")
  for l in lits {
    let v = lit_var(l) + 1
    if lit_is_neg(l) {
      buf.write_string("-\{v} ")
    } else {
      buf.write_string("\{v} ")
    }
  }
  buf.write_string("0\n")
  self.lines.push(buf.to_string())
}

///|
pub fn Proof::empty(self : Proof) -> Unit {
  self.lines.push("0\n")
}

///|
/// DIMACS-style text of the whole proof.
pub fn Proof::text(self : Proof) -> String {
  let buf = StringBuilder()
  for line in self.lines {
    buf.write_string(line)
  }
  buf.to_string()
}

///|
/// CDCL SAT solver with two-watched-literal propagation, 1-UIP conflict
/// analysis, VSIDS branching, phase saving, restarts and an optional DRAT
/// proof log.
pub struct Solver {
  mut num_vars : Int
  clauses : Array[Clause]
  watches : Array[Array[Int]]
  assigns : Array[Int]
  levels : Array[Int]
  reasons : Array[Int]
  trail : Array[Lit]
  trail_lim : Array[Int]
  mut qhead : Int
  activity : Array[Double]
  mut var_inc : Double
  heap : Array[Int]
  heap_pos : Array[Int]
  phase : Array[Bool]
  mut ok : Bool
  mut decisions : Int
  mut propagations : Int
  mut conflicts : Int
  mut restarts : Int
  mut learnts : Array[Int]
  mut max_learnts : Int
  mut conflicts_until_restart : Int
  mut proof : Proof?
}

///|
pub fn Solver::new(formula : Formula) -> Solver {
  let n = formula.num_vars
  let watches : Array[Array[Int]] = []
  let mut i = 0
  while i < 2 * n {
    watches.push([])
    i = i + 1
  }
  let s : Solver = {
    num_vars : n,
    clauses : [],
    watches : watches,
    assigns : Array::make(n, -1),
    levels : Array::make(n, 0),
    reasons : Array::make(n, -1),
    trail : [],
    trail_lim : [],
    qhead : 0,
    activity : Array::make(n, 0.0),
    var_inc : 1.0,
    heap : [],
    heap_pos : Array::make(n, -1),
    phase : Array::make(n, true),
    ok : true,
    decisions : 0,
    propagations : 0,
    conflicts : 0,
    restarts : 0,
    learnts : [],
    max_learnts : 2000,
    conflicts_until_restart : 100,
    proof : None,
  }
  let mut v = 0
  while v < n {
    s.heap_push(v)
    v = v + 1
  }
  for c in formula.clauses {
    s.add_original(c)
  }
  s
}

///|
/// Allocate a fresh variable.  Used by encodings (cardinality constraints,
/// MaxSAT relaxations) that build on top of the solver.
pub fn Solver::new_var(self : Solver) -> Int {
  let v = self.num_vars
  self.num_vars = v + 1
  self.assigns.push(-1)
  self.levels.push(0)
  self.reasons.push(-1)
  self.activity.push(0.0)
  self.phase.push(true)
  self.heap_pos.push(-1)
  self.watches.push([])
  self.watches.push([])
  self.heap_push(v)
  v
}

///|
pub fn Solver::enable_proof(self : Solver) -> Proof {
  let p = Proof::new()
  self.proof = Some(p)
  p
}

///|
pub fn Solver::value_lit(self : Solver, l : Lit) -> Int {
  let v = lit_var(l)
  let a = self.assigns[v]
  if a < 0 {
    -1
  } else if lit_is_neg(l) {
    1 - a
  } else {
    a
  }
}

///|
pub fn Solver::decision_level(self : Solver) -> Int {
  self.trail_lim.length()
}

///|
fn Solver::new_decision_level(self : Solver) -> Unit {
  self.trail_lim.push(self.trail.length())
}

///|
fn Solver::enqueue(self : Solver, l : Lit, reason : Int) -> Unit {
  let v = lit_var(l)
  self.assigns[v] = if lit_is_neg(l) {
    0
  } else {
    1
  }
  self.levels[v] = self.decision_level()
  self.reasons[v] = reason
  self.phase[v] = !lit_is_neg(l)
  self.trail.push(l)
}

///|
fn Solver::cancel_until(self : Solver, level : Int) -> Unit {
  let had_backtrack = self.trail_lim.length() > level
  while self.trail_lim.length() > level {
    let lim = self.trail_lim.pop().unwrap()
    while self.trail.length() > lim {
      let l = self.trail.pop().unwrap()
      let v = lit_var(l)
      self.assigns[v] = -1
      self.reasons[v] = -1
      self.levels[v] = 0
      self.heap_push(v)
    }
  }
  if had_backtrack {
    self.qhead = self.trail.length()
  }
}

///|
/// Add a clause from the original formula (constructor time).
fn Solver::add_original(self : Solver, c : Clause) -> Unit {
  let ci = self.clauses.length()
  self.clauses.push(c)
  let size = c.size()
  if size == 0 {
    self.ok = false
    return
  }
  if size == 1 {
    let l = c.lits[0]
    if self.value_lit(l) == 0 {
      self.ok = false
    } else if self.value_lit(l) < 0 {
      self.enqueue(l, ci)
    }
    return
  }
  self.watches[c.lits[0]].push(ci)
  self.watches[c.lits[1]].push(ci)
}

///|
/// Two-watched-literal propagation.  Returns a conflicting clause index or
/// `-1` when propagation completes without conflict.
fn Solver::propagate(self : Solver) -> Int {
  while self.qhead < self.trail.length() {
    let p = self.trail[self.qhead]
    self.propagations = self.propagations + 1
    self.qhead = self.qhead + 1
    let idx = lit_neg(p)
    let ws = self.watches[idx]
    let mut i = 0
    let mut j = 0
    let mut conflict = -1
    while i < ws.length() {
      let ci = ws[i]
      let c = self.clauses[ci]
      if c.dead {
        i = i + 1
        continue
      }
      let w = if c.lits[c.watch0] == lit_neg(p) {
        0
      } else if c.lits[c.watch1] == lit_neg(p) {
        1
      } else {
        -1
      }
      if w < 0 {
        i = i + 1
        continue
      }
      let other = c.lits[c.watch_at(1 - w)]
      if self.value_lit(other) == 1 {
        ws[j] = ci
        j = j + 1
        i = i + 1
        continue
      }
      let mut found = -1
      let mut k = 0
      while k < c.lits.length() {
        if k != c.watch0 && k != c.watch1 && self.value_lit(c.lits[k]) != 0 {
          found = k
          break
        }
        k = k + 1
      }
      if found >= 0 {
        c.move_watch(w, found)
        self.watches[c.lits[found]].push(ci)
        i = i + 1
        continue
      }
      if self.value_lit(other) < 0 {
        self.enqueue(other, ci)
        ws[j] = ci
        j = j + 1
        i = i + 1
        continue
      }
      conflict = ci
      ws[j] = ci
      j = j + 1
      i = i + 1
      break
    }
    while i < ws.length() {
      ws[j] = ws[i]
      j = j + 1
      i = i + 1
    }
    let nw : Array[Int] = []
    let mut t = 0
    while t < j {
      nw.push(ws[t])
      t = t + 1
    }
    self.watches[idx] = nw
    if conflict >= 0 {
      return conflict
    }
  }
  -1
}

///|
fn Solver::bump_var(self : Solver, v : Int) -> Unit {
  self.activity[v] = self.activity[v] + self.var_inc
  if self.activity[v] > 1.0e100 {
    let mut i = 0
    while i < self.num_vars {
      self.activity[i] = self.activity[i] / 1.0e100
      i = i + 1
    }
    self.var_inc = self.var_inc / 1.0e100
  }
  if self.heap_pos[v] >= 0 {
    self.heap_up(self.heap_pos[v])
  }
}

///|
fn Solver::decay_var_inc(self : Solver) -> Unit {
  self.var_inc = self.var_inc * 1.0526315789473684
}

///|
fn Solver::heap_less(self : Solver, a : Int, b : Int) -> Bool {
  self.activity[a] > self.activity[b]
}

///|
fn Solver::heap_swap(self : Solver, i : Int, j : Int) -> Unit {
  let a = self.heap[i]
  let b = self.heap[j]
  self.heap[i] = b
  self.heap[j] = a
  self.heap_pos[a] = j
  self.heap_pos[b] = i
}

///|
fn Solver::heap_up(self : Solver, i : Int) -> Unit {
  let mut i = i
  while i > 0 {
    let parent = (i - 1) / 2
    if self.heap_less(self.heap[i], self.heap[parent]) {
      self.heap_swap(i, parent)
      i = parent
    } else {
      break
    }
  }
}

///|
fn Solver::heap_down(self : Solver, i : Int) -> Unit {
  let mut i = i
  let n = self.heap.length()
  while true {
    let l = 2 * i + 1
    let r = 2 * i + 2
    let mut best = i
    if l < n && self.heap_less(self.heap[l], self.heap[best]) {
      best = l
    }
    if r < n && self.heap_less(self.heap[r], self.heap[best]) {
      best = r
    }
    if best == i {
      break
    }
    self.heap_swap(i, best)
    i = best
  }
}

///|
fn Solver::heap_push(self : Solver, v : Int) -> Unit {
  if self.heap_pos[v] >= 0 {
    return
  }
  self.heap_pos[v] = self.heap.length()
  self.heap.push(v)
  self.heap_up(self.heap.length() - 1)
}

///|
fn Solver::heap_pop(self : Solver) -> Int {
  if self.heap.length() == 0 {
    return -1
  }
  let top = self.heap[0]
  self.heap_pos[top] = -1
  let last = self.heap.pop().unwrap()
  if self.heap.length() > 0 {
    self.heap[0] = last
    self.heap_pos[last] = 0
    self.heap_down(0)
  }
  top
}

///|
fn Solver::pick_branch(self : Solver) -> Lit {
  while true {
    let v = self.heap_pop()
    if v < 0 {
      return -1
    }
    if self.assigns[v] < 0 {
      self.decisions = self.decisions + 1
      return lit_new(v, !self.phase[v])
    }
  }
  -1
}

///|
/// 1-UIP conflict analysis.  Returns the learnt clause and the level to
/// backjump to.  The asserting literal is placed at index 0.
fn Solver::analyze(self : Solver, confl : Int) -> (Array[Lit], Int) {
  let learnt : Array[Lit] = []
  let seen : Array[Bool] = Array::make(self.num_vars, false)
  let mut path_c = 0
  let mut p : Lit = -1
  let mut idx = self.trail.length() - 1
  let mut ci = confl
  while true {
    let c = self.clauses[ci]
    for q in c.lits {
      if q != p {
        let v = lit_var(q)
        if !seen[v] && self.levels[v] > 0 {
          seen[v] = true
          self.bump_var(v)
          if self.levels[v] == self.decision_level() {
            path_c = path_c + 1
          } else {
            learnt.push(q)
          }
        }
      }
    }
    while idx >= 0 && !seen[lit_var(self.trail[idx])] {
      idx = idx - 1
    }
    if idx < 0 {
      break
    }
    p = self.trail[idx]
    ci = self.reasons[lit_var(p)]
    seen[lit_var(p)] = false
    path_c = path_c - 1
    idx = idx - 1
    if path_c <= 0 {
      break
    }
  }
  let asserting = lit_neg(p)
  let out : Array[Lit] = [asserting]
  for l in learnt {
    out.push(l)
  }
  for l in out {
    seen[lit_var(l)] = false
  }
  let mut bt = 0
  if out.length() > 1 {
    let mut max_i = 1
    let mut i = 2
    while i < out.length() {
      if self.levels[lit_var(out[i])] > self.levels[lit_var(out[max_i])] {
        max_i = i
      }
      i = i + 1
    }
    let t = out[1]
    out[1] = out[max_i]
    out[max_i] = t
    bt = self.levels[lit_var(out[1])]
  }
  (out, bt)
}

///|
/// Compute the literal block distance of a clause (number of distinct
/// decision levels), used for clause-database reduction.
fn Solver::compute_lbd(self : Solver, lits : Array[Lit]) -> Int {
  let seen : Array[Bool] = Array::make(self.decision_level() + 1, false)
  let mut count = 0
  for l in lits {
    let lv = self.levels[lit_var(l)]
    if lv <= self.decision_level() && !seen[lv] {
      seen[lv] = true
      count = count + 1
    }
  }
  count
}

///|
fn Solver::add_learnt(self : Solver, lits : Array[Lit]) -> Int {
  let ci = self.clauses.length()
  let c = Clause::new(lits, true)
  c.set_lbd(self.compute_lbd(lits))
  self.clauses.push(c)
  self.learnts.push(ci)
  if self.proof is Some(p) {
    p.add(lits)
  }
  if lits.length() >= 2 {
    self.watches[lits[0]].push(ci)
    self.watches[lits[1]].push(ci)
  }
  ci
}

///|
/// Reduce the learnt clause database: drop the less active half, keeping
/// clauses that are locked (reason of a current assignment) or have LBD <= 2.
fn Solver::reduce_db(self : Solver) -> Unit {
  if self.learnts.length() < self.max_learnts {
    return
  }
  let locked : Array[Bool] = Array::make(self.clauses.length(), false)
  let mut i = 0
  while i < self.num_vars {
    let r = self.reasons[i]
    if r >= 0 && self.assigns[i] >= 0 {
      locked[r] = true
    }
    i = i + 1
  }
  // Sort learnt clause indices by activity (ascending) so the tail is removed.
  let cand : Array[Int] = []
  for ci in self.learnts {
    let c = self.clauses[ci]
    if c.lbd > 2 && !locked[ci] {
      cand.push(ci)
    }
  }
  let sorted = self.sort_by_activity(cand)
  let remove_count = sorted.length() / 2
  let mut r = 0
  while r < remove_count {
    let ci = sorted[r]
    let c = self.clauses[ci]
    if self.proof is Some(p) {
      p.delete(c.lits)
    }
    c.mark_dead()
    r = r + 1
  }
  let alive : Array[Int] = []
  for ci in self.learnts {
    if !self.clauses[ci].dead {
      alive.push(ci)
    }
  }
  self.learnts = alive
  self.max_learnts = if self.max_learnts * 3 / 2 > 2000 {
    self.max_learnts * 3 / 2
  } else {
    2000
  }
}

///|
/// Insertion sort by activity, ascending.  Learnt DBs are small enough that
/// this stays cheap and keeps the code dependency-free.
fn Solver::sort_by_activity(self : Solver, xs : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for x in xs {
    out.push(x)
  }
  let mut i = 1
  while i < out.length() {
    let cur = out[i]
    let mut j = i
    while j > 0 && self.clauses[out[j - 1]].activity < self.clauses[cur].activity {
      out[j] = out[j - 1]
      j = j - 1
    }
    out[j] = cur
    i = i + 1
  }
  out
}

///|
/// Main CDCL search.  `assumptions` are temporary decisions on top of level 0.
pub fn Solver::solve(self : Solver, assumptions : Array[Lit]) -> Bool {
  if !self.ok {
    if self.proof is Some(p) {
      p.empty()
    }
    return false
  }
  self.cancel_until(0)
  let confl0 = self.propagate()
  if confl0 >= 0 {
    self.ok = false
    if self.proof is Some(p) {
      p.empty()
    }
    return false
  }
  for a in assumptions {
    let val = self.value_lit(a)
    if val == 0 {
      return false
    }
    if val < 0 {
      self.new_decision_level()
      self.enqueue(a, -1)
    }
    let confl = self.propagate()
    if confl >= 0 {
      return false
    }
  }
  while true {
    let confl = self.propagate()
    if confl >= 0 {
      self.conflicts = self.conflicts + 1
      self.conflicts_until_restart = self.conflicts_until_restart - 1
      if self.decision_level() == 0 {
        self.ok = false
        if self.proof is Some(p) {
      p.empty()
    }
        return false
      }
      let (learnt, bt) = self.analyze(confl)
      self.cancel_until(bt)
      let ci = self.add_learnt(learnt)
      if learnt.length() == 1 {
        self.enqueue(learnt[0], -1)
      } else {
        self.enqueue(learnt[0], ci)
      }
      self.decay_var_inc()
      self.reduce_db()
    } else {
      if self.conflicts_until_restart <= 0 {
        self.restarts = self.restarts + 1
        self.conflicts_until_restart = 100 * (self.restarts + 1)
        self.cancel_until(0)
        self.qhead = self.trail.length()
        continue
      }
      let next = self.pick_branch()
      if next < 0 {
        return true
      }
      self.new_decision_level()
      self.enqueue(next, -1)
    }
  } nobreak {
    false
  }
}

///|
/// Current model as a per-variable boolean array.
pub fn Solver::model(self : Solver) -> Array[Bool] {
  let out : Array[Bool] = []
  let mut i = 0
  while i < self.num_vars {
    out.push(self.assigns[i] == 1)
    i = i + 1
  }
  out
}

///|
/// Incrementally add a clause on top of the current state.  The solver
/// backtracks to level 0 first, so learnt clauses and activities are kept.
pub fn Solver::add_clause(self : Solver, lits : Array[Lit]) -> Bool {
  if !self.ok {
    return false
  }
  if self.decision_level() > 0 {
    self.cancel_until(0)
  }
  let mut satisfied = false
  let unassigned : Array[Lit] = []
  for l in lits {
    let val = self.value_lit(l)
    if val == 1 {
      satisfied = true
      break
    } else if val < 0 {
      unassigned.push(l)
    }
  }
  if satisfied {
    return true
  }
  let ci = self.clauses.length()
  let c = Clause::new(unassigned, false)
  self.clauses.push(c)
  if unassigned.length() == 0 {
    self.ok = false
    return false
  } else if unassigned.length() == 1 {
    self.enqueue(unassigned[0], ci)
    let confl = self.propagate()
    if confl >= 0 {
      self.ok = false
      return false
    }
  } else {
    self.watches[unassigned[0]].push(ci)
    self.watches[unassigned[1]].push(ci)
  }
  true
}

///|
/// Statistics rendered as a single line, useful for benchmarks and CI output.
pub fn Solver::stats_string(self : Solver) -> String {
  "decisions=\{self.decisions} propagations=\{self.propagations} conflicts=\{self.conflicts} restarts=\{self.restarts} learnts=\{self.learnts.length()}"
}
