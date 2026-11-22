///|
test "comment and verdict lines are not parsed as clauses" {
  let f = parse_dimacs(
    "p cnf 6 9\n1 2 0\n3 4 0\n5 6 0\n-1 -3 0\n-1 -5 0\n-3 -5 0\n-2 -4 0\n-2 -6 0\n-4 -6 0\n",
  )
  // 命令行会把 `s` 与一行 `c …` 统计贴在证明后面，抄过去不应改变结论。
  let text = "s UNSATISFIABLE\n-1 0\n0\nc decisions=1 propagations=9 conflicts=2 restarts=0 learnts=1 minimised=0\n"
  assert_true(verify_proof(f, text))
}

///|
test "a proof made only of comments is rejected instead of crashing" {
  let f = parse_dimacs("p cnf 2 2\n1 0\n-1 0\n")
  assert_false(verify_proof(f, "c only comments here\ns UNSATISFIABLE\n"))
}

///|
test "a trailing comment after the empty clause still verifies" {
  let f = parse_dimacs("p cnf 2 2\n1 0\n-1 0\n")
  assert_true(verify_proof(f, "1 0\n0\nc done\n"))
}
