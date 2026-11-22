///|
test "lower bound proof checks out for an unreachable cost" {
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n1 -1 0\n")
  let proof = maxsat_bound_proof(w, 0).unwrap()
  assert_true(proof.length() > 0)
  assert_true(verify_maxsat_bound(w, 0, proof))
}

///|
test "no proof is produced when the bound is reachable" {
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n1 -1 0\n")
  assert_true(maxsat_bound_proof(w, 1) is None)
}

///|
test "a truncated proof is rejected" {
  let w = parse_wcnf(
    "p wcnf 4 6 10\n10 1 2 0\n10 3 4 0\n1 -1 0\n1 -2 0\n1 -3 0\n1 -4 0\n",
  )
  assert_true(maxsat_solve(w, 64) == 2)
  let proof = maxsat_bound_proof(w, 1).unwrap()
  assert_true(verify_maxsat_bound(w, 1, proof))
  let lines : Array[StringView] = []
  for l in proof.split("\n") {
    if l.trim().length() > 0 {
      lines.push(l)
    }
  }
  assert_true(lines.length() > 1)
  // 校验器要求证明以空子句收尾：去掉它，结论就不再成立。
  let mut body = ""
  for l in lines {
    let t = l.trim().to_owned()
    if t != "0" {
      body = body + t + "\n"
    }
  }
  assert_false(verify_maxsat_bound(w, 1, body))
}

///|
test "the optimality bound of a scheduling instance verifies" {
  let w = parse_wcnf(
    "p wcnf 4 7 10\n10 1 2 0\n10 3 4 0\n10 -1 -3 0\n10 -2 -4 0\n3 1 0\n1 -1 0\n2 4 0\n",
  )
  assert_true(maxsat_solve(w, 64) == 1)
  let proof = maxsat_bound_proof(w, 0).unwrap()
  assert_true(verify_maxsat_bound(w, 0, proof))
}

///|
test "a proof does not carry over to a different bound" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  let proof = maxsat_bound_proof(w, 0).unwrap()
  assert_true(verify_maxsat_bound(w, 0, proof))
  assert_false(verify_maxsat_bound(w, 1, proof))
}

///|
test "unsatisfiable hard clauses still give a checkable bound proof" {
  let w = parse_wcnf("p wcnf 1 2 10\n10 1 0\n10 -1 0\n")
  assert_true(maxsat_core_bound(w) == -1)
  assert_true(maxsat_solve(w, 64) == -1)
  let proof = maxsat_bound_proof(w, 0).unwrap()
  assert_true(verify_maxsat_bound(w, 0, proof))
}

///|
/// The encoding exported by `maxsat-cnf` is what an external checker sees, so
/// it has to survive a DIMACS round trip without losing a clause or a variable.
test "the encoding survives a dimacs round trip" {
  let w = parse_wcnf("p wcnf 2 3 10\n10 1 2 0\n1 -1 0\n1 -2 0\n")
  let enc = maxsat_encoding(w, 0)
  let text = to_dimacs(enc)
  let back = try parse_dimacs(text) catch {
    e => abort("the exported encoding does not parse: \{e}")
  }
  assert_true(back.num_vars == enc.num_vars)
  assert_true(back.clauses.length() == enc.clauses.length())
  // cost 0 forces both soft clauses to hold, which contradicts the hard clause.
  let s0 = Solver::new(back)
  assert_false(s0.solve([]))
  // cost 1 is affordable, so bound 1 has to come out satisfiable.
  let s1 = Solver::new(parse_dimacs(to_dimacs(maxsat_encoding(w, 1))))
  assert_true(s1.solve([]))
}
