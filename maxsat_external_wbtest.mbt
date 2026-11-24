///|
test "inputs from outside are accepted when both halves hold" {
  // Petersen 最小顶点覆盖：10 个顶点、15 条边，最优覆盖 6 个顶点，软权重 100，
  // 所以 opt = 600，下界要证的是「代价 ≤ 599 不可达」。
  let w = parse_wcnf(weighted_vertex_cover_wcnf(10, petersen_edges(), 100))
  let (model, cost) = maxsat_solution(w, 4096).unwrap()
  assert_true(cost == 600)
  let proof = maxsat_bound_proof(w, cost - 1).unwrap()
  let (upper, lower) = verify_maxsat_external(w, cost, model, proof)
  assert_true(upper)
  assert_true(lower)
}

///|
test "an assignment that does not pay the claimed cost is rejected" {
  let w = parse_wcnf(weighted_vertex_cover_wcnf(10, petersen_edges(), 100))
  let (model, cost) = maxsat_solution(w, 4096).unwrap()
  let proof = maxsat_bound_proof(w, cost - 1).unwrap()
  // 翻转第一个变量：要么破坏硬子句，要么让代价涨 100，两种都过不了上界。
  let flipped : Array[Bool] = []
  let mut i = 0
  while i < model.length() {
    flipped.push(if i == 0 { !model[i] } else { model[i] })
    i = i + 1
  }
  let (upper, lower) = verify_maxsat_external(w, cost, flipped, proof)
  assert_false(upper)
  // 下界只依赖证明，与赋值无关。
  assert_true(lower)
}

///|
test "a proof without its empty clause is rejected even if the assignment is right" {
  let w = parse_wcnf(weighted_vertex_cover_wcnf(10, petersen_edges(), 100))
  let (model, cost) = maxsat_solution(w, 4096).unwrap()
  let proof = maxsat_bound_proof(w, cost - 1).unwrap()
  // 去掉最后一个非空行（也就是那个单独的空子句 `0`）。
  let lines : Array[String] = []
  for raw in proof.split("\n") {
    lines.push(raw.to_owned())
  }
  let mut last = -1
  let mut j = 0
  while j < lines.length() {
    if lines[j].trim().length() > 0 {
      last = j
    }
    j = j + 1
  }
  let mut tampered = ""
  let mut k = 0
  while k < lines.length() {
    if k != last {
      tampered = tampered + lines[k] + "\n"
    }
    k = k + 1
  }
  let (upper, lower) = verify_maxsat_external(w, cost, model, tampered)
  assert_true(upper)
  assert_false(lower)
}
