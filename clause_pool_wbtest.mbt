///|
test "dropped clauses give their literal buffers back" {
  let f = Formula::new(4)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  let s = Solver::new(f)
  let mut i = 0
  while i < 2500 {
    let ci = s.add_learnt([
      lit_new(0, false),
      lit_new(1, false),
      lit_new(2, false),
    ])
    s.clauses[ci].set_lbd(3)
    s.clauses[ci].add_activity(1.0)
    i = i + 1
  }
  s.reduce_db()
  let mut dead = 0
  let mut leaked = 0
  for c in s.clauses {
    if c.dead {
      dead = dead + 1
      if c.size() > 0 {
        leaked = leaked + 1
      }
    }
  }
  // Half the candidates go; every one of them must have released its buffer.
  assert_eq(dead, 1250)
  assert_eq(leaked, 0)
  assert_eq(s.learnts.length(), 1250)
}

///|
test "the search still finishes correctly after the database shrinks" {
  // 8 pigeons into 7 holes: enough conflicts to trigger a reduction, and the
  // verdict has to stay UNSAT while propagation keeps walking a database that
  // holds emptied clauses.
  assert_false(Solver::new(pigeonhole(8, 7)).solve([]))
}
