///|
/// Build a WCNF text for the minimum vertex cover problem on the given edge
/// list: one hard clause (u v) per edge and one soft clause (-v) of weight 1
/// per vertex.  Picking vertex v into the cover sets variable v to true.
fn vertex_cover_wcnf(vertices : Int, edges : Array[(Int, Int)]) -> String {
  let mut text = "p wcnf \{vertices} \{edges.length() + vertices} 2\n"
  for e in edges {
    let (u, v) = e
    text = text + "2 \{u} \{v} 0\n"
  }
  let mut v = 1
  while v <= vertices {
    text = text + "1 -\{v} 0\n"
    v = v + 1
  }
  text
}

///|
test "petersen graph vertex cover optimum is six" {
  // Outer pentagon 1-2-3-4-5-1, inner star 6-8-10-7-9-6, spokes 1-6 .. 5-10.
  let edges : Array[(Int, Int)] = [
    (1, 2), (2, 3), (3, 4), (4, 5), (5, 1),
    (6, 8), (8, 10), (10, 7), (7, 9), (9, 6),
    (1, 6), (2, 7), (3, 8), (4, 9), (5, 10),
  ]
  let w = parse_wcnf(vertex_cover_wcnf(10, edges))
  assert_eq(maxsat_solve(w, 64), 6)
}

///|
test "4x5 grid vertex cover optimum is ten" {
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
  r = 0
  while r < 3 {
    let mut c = 0
    while c < 5 {
      let u = r * 5 + c + 1
      edges.push((u, u + 5))
      c = c + 1
    }
    r = r + 1
  }
  assert_true(edges.length() == 31)
  let w = parse_wcnf(vertex_cover_wcnf(20, edges))
  assert_eq(maxsat_solve(w, 64), 10)
}

///|
test "vertex cover instances give a core lower bound below the optimum" {
  let edges : Array[(Int, Int)] = [
    (1, 2), (2, 3), (3, 4), (4, 5), (5, 1),
    (6, 8), (8, 10), (10, 7), (7, 9), (9, 6),
    (1, 6), (2, 7), (3, 8), (4, 9), (5, 10),
  ]
  let w = parse_wcnf(vertex_cover_wcnf(10, edges))
  let bound = maxsat_core_bound(w)
  assert_true(bound >= 0)
  assert_true(bound <= maxsat_solve(w, 64))
}
