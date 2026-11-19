///|
test "core bound is zero when all soft clauses fit together" {
  let w = parse_wcnf("p wcnf 2 2 10\n10 1 0\n1 2 0\n")
  assert_true(maxsat_core_bound(w) == 0)
}

///|
test "core bound matches the cheapest violated clause" {
  // 硬子句 (x0)：软子句 (¬x0) 无法同时满足，权重 1 是下界。
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n1 -1 0\n")
  assert_true(maxsat_core_bound(w) == 1)
  assert_true(maxsat_solve(w, 64) == 1)
}

///|
test "core bound on a conflicting pair of soft clauses" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  let bound = maxsat_core_bound(w)
  let opt = maxsat_solve(w, 64)
  assert_true(bound > 0)
  assert_true(bound <= opt)
  assert_true(opt == 1)
}

///|
test "core bound is minus one when the hard clauses clash" {
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n10 -1 0\n")
  assert_true(maxsat_core_bound(w) == -1)
  assert_true(maxsat_solve(w, 64) == -1)
}

///|
test "core bound never exceeds the optimum on fixed instances" {
  let texts = [
    "p wcnf 2 3 10\n10 1 0\n1 2 0\n1 -2 0\n",
    "p wcnf 2 4 10\n10 1 2 0\n10 -1 -2 0\n1 1 0\n1 -1 0\n",
    "p wcnf 3 4 10\n10 1 2 3 0\n1 -1 0\n1 -2 0\n1 -3 0\n",
    "p wcnf 3 5 10\n10 1 2 0\n10 -1 3 0\n1 -3 0\n1 -2 0\n1 2 0\n",
  ]
  for t in texts {
    let w = parse_wcnf(t)
    let bound = maxsat_core_bound(w)
    let opt = maxsat_solve(w, 128)
    if opt < 0 {
      assert_true(bound == -1)
    } else {
      assert_true(bound >= 0)
      assert_true(bound <= opt)
    }
  }
}
