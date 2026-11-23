///|
test "a drat line naming a variable the formula never declares is rejected" {
  // 公式只有 2 个变量，证明里写 `999 0`。以前这会索引到检查器数组之外并让进程
  // abort（native 下 SIGABRT），现在判为无效证明。
  let f = parse_dimacs("p cnf 2 1\n1 2 0\n")
  let steps = parse_drat("999 0\n0\n")
  assert_false(check_drat(f, steps))
  assert_false(check_drat_rat(f, steps))
}

///|
test "an in-range proof still verifies" {
  // 单元子句池自身就矛盾，空子句是 RUP；变量都在公式范围内，守卫不应拦下它。
  let f = parse_dimacs("p cnf 1 2\n1 0\n-1 0\n")
  let steps = parse_drat("0\n")
  assert_true(check_drat(f, steps))
}

///|
test "the guard keeps the trailing empty clause from being credited" {
  // 越界行出现在空子句之前时，整份证明被拒，不会因为后面有 `0` 就判成功。
  let f = parse_dimacs("p cnf 3 1\n1 2 3 0\n")
  let steps = parse_drat("4 0\n0\n")
  assert_false(check_drat(f, steps))
}
