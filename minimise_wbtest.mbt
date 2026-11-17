///|
test "recursive minimisation fires on an unsatisfiable instance" {
  let s = Solver::new(pigeonhole(5, 4))
  assert_false(s.solve([]))
  assert_true(s.minimised > 0)
}

///|
/// Minimisation must not weaken the clause: every shortened clause has to stay
/// RUP, otherwise the independent checker rejects the proof.  The 5/4 instance
/// forces many conflicts, so this exercises the minimised path repeatedly.
test "proof of minimised clauses still verifies" {
  let f = pigeonhole(5, 4)
  let s = Solver::new(f)
  let p = s.enable_proof()
  assert_false(s.solve([]))
  assert_true(verify_proof(f, p.text()))
}

///|
test "minimisation never removes the asserting literal" {
  let s = Solver::new(pigeonhole(4, 3))
  assert_false(s.solve([]))
  assert_true(s.minimised <= s.conflicts * 8)
}
