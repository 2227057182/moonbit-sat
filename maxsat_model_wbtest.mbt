///|
test "an optimal assignment pays the claimed cost" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  let (model, cost) = maxsat_solution(w, 64).unwrap()
  assert_true(cost == 1)
  assert_true(verify_maxsat_solution(w, model, cost))
  assert_true(maxsat_model_cost(w, model) == cost)
}

///|
test "a claim that does not match the assignment is rejected" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  let (model, cost) = maxsat_solution(w, 64).unwrap()
  assert_false(verify_maxsat_solution(w, model, cost + 1))
  assert_false(verify_maxsat_solution(w, model, cost - 1))
}

///|
test "a model breaking a hard clause is rejected" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  let (model, cost) = maxsat_solution(w, 64).unwrap()
  // 让硬子句 (x1 ∨ x2) 两边都为假。
  let broken : Array[Bool] = []
  let mut i = 0
  while i < model.length() {
    broken.push(false)
    i = i + 1
  }
  assert_true(maxsat_model_cost(w, broken) == -1)
  assert_false(verify_maxsat_solution(w, broken, cost))
}

///|
test "a zero-cost instance still yields a checkable assignment" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 -1 -2 0\n1 -1 0\n2 -2 0\n")
  let (model, cost) = maxsat_solution(w, 64).unwrap()
  assert_true(cost == 0)
  assert_true(verify_maxsat_solution(w, model, cost))
}

///|
test "unsatisfiable hard clauses produce no assignment" {
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n10 -1 0\n")
  assert_true(maxsat_solution(w, 64) is None)
  assert_true(maxsat_model_cost(w, [true]) == -1)
}

///|
test "the vertex cover optimum comes with a matching assignment" {
  let w = parse_wcnf(
    "p wcnf 4 6 10\n10 1 2 0\n10 3 4 0\n1 -1 0\n1 -2 0\n1 -3 0\n1 -4 0\n",
  )
  let (model, cost) = maxsat_solution(w, 64).unwrap()
  assert_true(cost == 2)
  assert_true(verify_maxsat_solution(w, model, cost))
  // 上界与下界合起来才叫最优：4 条软子句全部满足需要覆盖两组，代价为 0 不可达。
  assert_true(verify_maxsat_bound(w, cost - 1, maxsat_bound_proof(w, cost - 1).unwrap()))
}
