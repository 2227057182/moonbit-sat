///|
/// `(x1 ∨ x2) ∧ (¬x1 ∨ x2)` with the empty-clause requirement switched off:
/// adding `(x1)` is not RUP (the negation leaves `x2` true and no conflict),
/// but it is RAT because the only resolvent `(x2)` is itself RUP.
test "RAT accepts a clause that RUP rejects" {
  let f = Formula::new(2)
  f.add([lit_new(0, false), lit_new(1, false)]) |> ignore
  f.add([lit_new(0, true), lit_new(1, false)]) |> ignore
  let steps = parse_drat("1 0\n")
  assert_false(check_steps(f, steps, false, false))
  assert_true(check_steps(f, steps, true, false))
}

///|
/// Adding `(x1)` here is unsound: two pool clauses carry the negated pivot and
/// the resolvent `(x2)` is neither a tautology nor a RUP consequence.
test "RAT rejects an unjustified clause" {
  let f = Formula::new(3)
  f.add([lit_new(0, true), lit_new(1, false)]) |> ignore
  f.add([lit_new(0, true), lit_new(2, false)]) |> ignore
  let steps = parse_drat("1 0\n")
  assert_false(check_steps(f, steps, true, false))
}

///|
/// A fresh variable has no negated occurrence in the pool, so any clause on it
/// is RAT vacuously — the case that makes definition steps legal in DRAT.
test "RAT accepts a fresh-variable clause vacuously" {
  let f = Formula::new(3)
  f.add([lit_new(0, true), lit_new(1, false)]) |> ignore
  let steps = parse_drat("3 1 0\n")
  assert_true(check_steps(f, steps, true, false))
  assert_false(check_steps(f, steps, false, false))
}

///|
/// The CDCL core still emits RUP-only proofs, so the strict and the full
/// checker must agree on everything the solver produces.
test "solver proofs verify under both modes" {
  let f = pigeonhole(5, 4)
  let s = Solver::new(f)
  let p = s.enable_proof()
  assert_false(s.solve([]))
  assert_true(verify_proof(f, p.text()))
  assert_true(verify_proof_rat(f, p.text()))
}
