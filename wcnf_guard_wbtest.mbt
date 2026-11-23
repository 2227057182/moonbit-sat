///|
test "a well formed wcnf reports no error" {
  let w = parse_wcnf("p wcnf 2 2 100\n100 1 0\n5 -1 0\n")
  assert_true(
    match wcnf_error(w) {
      None => true
      Some(_) => false
    },
  )
}

///|
test "a wcnf without a header is rejected" {
  // 没有 `p wcnf` 行时 top 保持 0，所有子句都变成硬子句——以前是静默改判。
  let w = parse_wcnf("5 -1 0\n100 1 0\n")
  assert_true(
    match wcnf_error(w) {
      None => false
      Some(_) => true
    },
  )
}

///|
test "a header without a top is rejected" {
  let w = parse_wcnf("p wcnf 2 2\n5 -1 0\n100 1 0\n")
  assert_true(
    match wcnf_error(w) {
      None => false
      Some(_) => true
    },
  )
}

///|
test "a negative soft weight is rejected instead of crashing" {
  let w = parse_wcnf("p wcnf 2 2 100\n-5 -1 0\n100 1 0\n")
  assert_true(
    match wcnf_error(w) {
      None => false
      Some(_) => true
    },
  )
  // 库层面也要挡住：以前负权重让二分拿到负预算，最终在计数编码里越界 abort。
  let got = try {
    maxsat_solve(w, 64)
  } catch {
    _ => -999
  }
  assert_true(got == -999)
}

///|
test "a negative cost budget yields the empty clause" {
  let w = parse_wcnf("p wcnf 2 2 100\n100 1 0\n5 -1 0\n")
  let f = maxsat_encoding(w, -1)
  assert_true(f.num_vars == w.num_vars)
  let s = Solver::new(f)
  assert_false(s.solve([]))
}
