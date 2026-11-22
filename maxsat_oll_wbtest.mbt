///|
/// Vertex cover WCNF with a uniform soft weight, so the total soft weight can
/// be pushed past the 512 encoding cap and the core-guided loop is exercised
/// instead of the reformulation fast path.
fn weighted_vertex_cover_wcnf(
  vertices : Int,
  edges : Array[(Int, Int)],
  weight : Int,
) -> String {
  let mut text = "p wcnf \{vertices} \{edges.length() + vertices} \{weight + 1}\n"
  for e in edges {
    let (u, v) = e
    text = text + "\{weight + 1} \{u} \{v} 0\n"
  }
  let mut v = 1
  while v <= vertices {
    text = text + "\{weight} -\{v} 0\n"
    v = v + 1
  }
  text
}

///|
fn petersen_edges() -> Array[(Int, Int)] {
  [
    (1, 2), (2, 3), (3, 4), (4, 5), (5, 1),
    (6, 8), (8, 10), (10, 7), (7, 9), (9, 6),
    (1, 6), (2, 7), (3, 8), (4, 9), (5, 10),
  ]
}

///|
test "core-guided search matches the encoding search on a toy instance" {
  // Total soft weight 2: below the cap, so this also checks that the two entry
  // points agree where both are available.
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  assert_eq(maxsat_solve(w, 64), 1)
  assert_eq(maxsat_oll(w), 1)
}

///|
test "core-guided search handles a total soft weight above the encoding cap" {
  // 1200 of soft weight against the 512 cap: the core-guided loop never builds
  // a cardinality network, so it is not bounded by the total weight.
  let w = parse_wcnf(
    "p wcnf 2 5 5000\n5000 1 2 0\n300 -1 0\n300 -2 0\n300 -1 -2 0\n300 1 0\n",
  )
  // `1` is demanded true by one soft clause and false by another, so at least
  // one weight of 300 must be paid and nothing forces more.
  assert_eq(maxsat_oll(w), 300)
}

///|
test "core-guided search reports unsatisfiable hard clauses as minus one" {
  let w = parse_wcnf("p wcnf 1 3 10\n10 1 0\n10 -1 0\n1 1 0\n")
  assert_eq(maxsat_oll(w), -1)
}

///|
test "core-guided search returns zero when every soft clause is already free" {
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n1 1 0\n")
  assert_eq(maxsat_oll(w), 0)
}

///|
test "the core-guided model pays exactly the reported optimum" {
  let w = parse_wcnf(weighted_vertex_cover_wcnf(10, petersen_edges(), 100))
  let opt = maxsat_oll(w)
  assert_eq(opt, 600)
  match maxsat_oll_solution(w) {
    Some((model, cost)) => {
      assert_eq(cost, opt)
      assert_true(verify_maxsat_solution(w, model, cost))
    }
    None => assert_true(false)
  }
}

///|
test "core-guided search agrees with the encoding search on a 4x5 grid" {
  let edges : Array[(Int, Int)] = []
  let mut r = 0
  while r < 4 {
    let mut c = 0
    while c < 4 {
      let u = r * 5 + c + 1
      edges.push((u, u + 1))
      c = c + 1
    }
    r = r + 1
  }
  let mut c = 0
  while c < 5 {
    let mut r2 = 0
    while r2 < 3 {
      let u = r2 * 5 + c + 1
      edges.push((u, u + 5))
      r2 = r2 + 1
    }
    c = c + 1
  }
  assert_true(edges.length() == 31)
  // Weight 100 keeps the total at 2000, above the cap, so this goes through the
  // core-guided loop; the encoding path with a matching cap gives the reference.
  let w = parse_wcnf(weighted_vertex_cover_wcnf(20, edges, 100))
  assert_eq(maxsat_solve(w, 2000), 1000)
  assert_eq(maxsat_oll(w), 1000)
}

///|
test "core-guided search pays both cores of a dual-core instance" {
  // Two independent contradictions: pair (1,2) costs 100 and pair (3,4) costs
  // 500.  A single core-guided run has to pay both, so the optimum is 600.
  let w = parse_wcnf(
    "p wcnf 4 6 600\n600 1 2 0\n600 3 4 0\n100 -1 0\n100 -2 0\n500 -3 0\n500 -4 0\n",
  )
  assert_eq(maxsat_solve(w, 1200), 600)
  assert_eq(maxsat_oll(w), 600)
}

///|
test "core-guided search pays one weight layer at a time" {
  // The same clause appears in two cores: `-1` together with `1` costs 100,
  // and `-1` together with `-2 -3` costs another 100.  Weights are 100 and 300
  // so the total of 500 is still below the cap and the encoding path is the
  // reference.
  let w = parse_wcnf(
    "p wcnf 3 6 1000\n1000 1 2 3 0\n1000 1 2 0\n100 -1 0\n100 1 0\n300 -2 0\n300 -3 0\n",
  )
  let enc = maxsat_solve(w, 1000)
  assert_eq(maxsat_oll(w), enc)
}

///|
test "core-guided search takes a single expensive core" {
  let w = parse_wcnf("p wcnf 3 5 2000\n2000 1 2 0\n1000 -1 0\n1000 -2 0\n1 3 0\n1 -3 0\n")
  // Hard `1 2` forces one of the two 1000-weight clauses to be given up, and
  // the contradictory unit pair `3` / `-3` adds one more unit of cost.
  assert_eq(maxsat_oll(w), 1001)
}
