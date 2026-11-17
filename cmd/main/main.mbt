///|
fn decode(text : String) -> String {
  let sb = StringBuilder()
  for c in text {
    if c == ';' {
      sb.write_char('\n')
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Deterministic random 3-SAT near the satisfiability threshold.  Used by the
/// `bench` command so the search volume can be reproduced anywhere without
/// shipping instance files.
fn bench_formula(nv : Int, nc : Int, seed : Int) -> @lib.Formula {
  let f = @lib.Formula::new(nv)
  let mut st = seed
  let mut c = 0
  while c < nc {
    let a = st % nv
    st = (st * 1103 + 12345) % 65521
    let mut b = st % nv
    st = (st * 1103 + 12345) % 65521
    if b == a {
      b = (a + 1) % nv
    }
    let mut d = st % nv
    st = (st * 1103 + 12345) % 65521
    while d == a || d == b {
      d = (d + 1) % nv
    }
    let s1 = st % 2 == 1
    st = (st * 1103 + 12345) % 65521
    let s2 = st % 2 == 1
    st = (st * 1103 + 12345) % 65521
    let s3 = st % 2 == 1
    st = (st * 1103 + 12345) % 65521
    f.add([@lib.lit_new(a, s1), @lib.lit_new(b, s2), @lib.lit_new(d, s3)]) |> ignore
    c = c + 1
  }
  f
}

///|
fn run_bench() -> Unit {
  let sizes : Array[(Int, Int)] = [(20, 86), (30, 129), (40, 172), (50, 215), (60, 258)]
  for pair in sizes {
    let nv = pair.0
    let nc = pair.1
    let f = bench_formula(nv, nc, nv * 7 + 13)
    let s = @lib.Solver::new(f)
    let sat = s.solve([])
    println(
      "c bench vars=\{nv} clauses=\{nc} result=\{if sat { "SAT" } else { "UNSAT" }} \{s.stats_string()}",
    )
  }
}

///|
fn usage() -> Unit {
  println("moonbit-sat — CDCL SAT / MaxSAT toolkit")
  println("")
  println("usage:")
  println("  moonbit-sat solve  <dimacs>            solve a CNF, print SAT/UNSAT, model and stats")
  println("  moonbit-sat proof  <dimacs>            solve and print a DRAT proof when UNSAT")
  println("  moonbit-sat verify <dimacs> <proof>    independently check a DRAT proof (RUP only)")
  println("  moonbit-sat verify-rat <dimacs> <proof> check a DRAT proof with the RUP + RAT rule set")
  println("  moonbit-sat maxsat <wcnf>              optimal weighted MaxSAT cost")
  println("  moonbit-sat bench                      search volume on a fixed random 3-SAT ladder")
  println("")
  println("`;` in the argument is treated as a newline, so formulas can be passed inline.")
}

///|
fn main {
  let args = @env.args()
  if args.length() < 3 {
    if args.length() == 2 && args[1] == "bench" {
      run_bench()
      return
    }
    usage()
    return
  }
  let cmd = args[1]
  if cmd == "solve" || cmd == "proof" {
    let text = decode(args[2])
    try {
      let f = @lib.parse_dimacs(text)
      let s = @lib.Solver::new(f)
      let p = s.enable_proof()
      let sat = s.solve([])
      if sat {
        println("s SATISFIABLE")
        let model = s.model()
        let sb = StringBuilder()
        sb.write_string("v ")
        let mut i = 0
        while i < model.length() {
          sb.write_string(if model[i] { "\{i + 1} " } else { "-\{i + 1} " })
          i = i + 1
        }
        sb.write_string("0")
        println(sb.to_string())
      } else {
        println("s UNSATISFIABLE")
        if cmd == "proof" {
          println(p.text())
        }
      }
      println("c \{s.stats_string()}")
    } catch {
      e => println("c error: \{e}")
    }
  } else if cmd == "verify" || cmd == "verify-rat" {
    if args.length() < 4 {
      usage()
      return
    }
    try {
      let f = @lib.parse_dimacs(decode(args[2]))
      let proof = decode(args[3])
      let ok = if cmd == "verify-rat" {
        @lib.verify_proof_rat(f, proof)
      } else {
        @lib.verify_proof(f, proof)
      }
      println(if ok { "s VERIFIED" } else { "s PROOF-REJECTED" })
    } catch {
      e => println("c error: \{e}")
    }
  } else if cmd == "maxsat" {
    try {
      let w = @lib.parse_wcnf(decode(args[2]))
      let opt = @lib.maxsat_solve(w, 512)
      if opt < 0 {
        println("s UNSATISFIABLE (hard clauses)")
      } else {
        println("o \{opt}")
        println("s OPTIMUM FOUND")
      }
    } catch {
      e => println("c error: \{e}")
    }
  } else if cmd == "bench" {
    run_bench()
  } else {
    usage()
  }
}
