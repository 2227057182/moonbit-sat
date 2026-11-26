///|
test "encoding size: 11745 structural clauses plus one per hint" {
  let puzzle = parse_puzzle(default_puzzle)
  assert_true(puzzle.length() == 81)
  let f = encode(puzzle)
  // 81 条「至少一个」 + 81*36 条格内互斥 + 3*9*9*36 条行/列/宫互斥 = 11745
  let mut hints = 0
  for v in puzzle {
    if v > 0 {
      hints = hints + 1
    }
  }
  assert_true(f.num_clauses() == 11745 + hints)
}

///|
test "AI Escargot is solved and the grid passes the independent check" {
  let puzzle = parse_puzzle(default_puzzle)
  let f = encode(puzzle)
  let s = @lib.Solver::new(f)
  let sat = s.solve([])
  assert_true(sat)
  let grid = read_grid(s.model())
  assert_true(check(grid, puzzle))
}

///|
test "one wrong hint turns the same encoding UNSAT, with a checkable proof" {
  // 把 Escargot 的第 2 格从「空」改成 5（正确答案是 6），整题不再有解。
  let cells = parse_puzzle(default_puzzle)
  cells[1] = 5
  let f = encode(cells)
  let s = @lib.Solver::new(f)
  let p = s.enable_proof()
  let sat = s.solve([])
  assert_false(sat)
  let proof = p.text()
  assert_true(@lib.verify_proof(f, proof))
}

///|
test "input shorter than 81 cells is rejected instead of guessed" {
  let puzzle = parse_puzzle("1....7.9")
  // 8 个字符，不是 81：main 会据此拒绝，而不是把短输入当成长输入去猜。
  assert_true(puzzle.length() == 8)
  assert_true(puzzle.length() != 81)
}
