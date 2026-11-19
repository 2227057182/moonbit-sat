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
/// Pigeonhole encoding: `k` pigeons into `h` holes.  Unsatisfiable for k > h,
/// and the refutation needs many conflicts, so it makes a usable stress case
/// for the checker without shipping DIMACS files.
fn php_formula(k : Int, h : Int) -> @lib.Formula {
  let f = @lib.Formula::new(k * h)
  let mut p = 0
  while p < k {
    let lits : Array[Int32] = []
    let mut ho = 0
    while ho < h {
      lits.push(@lib.lit_new(p * h + ho, false))
      ho = ho + 1
    }
    f.add(lits) |> ignore
    p = p + 1
  }
  let mut ho2 = 0
  while ho2 < h {
    let mut p1 = 0
    while p1 < k {
      let mut p2 = p1 + 1
      while p2 < k {
        f.add([
          @lib.lit_new(p1 * h + ho2, true),
          @lib.lit_new(p2 * h + ho2, true),
        ]) |> ignore
        p2 = p2 + 1
      }
      p1 = p1 + 1
    }
    ho2 = ho2 + 1
  }
  f
}

///|
fn run_bench_verify(k : Int) -> Unit {
  let f = php_formula(k, k - 1)
  let s = @lib.Solver::new(f)
  let p = s.enable_proof()
  let sat = s.solve([])
  let text = p.text()
  let mut lines = 0
  for l in text.split("\n") {
    if l.trim().length() > 0 {
      lines = lines + 1
    }
  }
  let ok = @lib.verify_proof(f, text)
  println(
    "c verify k=\{k} vars=\{k * (k - 1)} proof_lines=\{lines} sat=\{sat} result=\{if ok { "VERIFIED" } else { "REJECTED" }}",
  )
}

///|
/// Parse a whitespace/comma separated list of DIMACS literals into assumptions.
fn parse_assumptions(text : String) -> Array[@lib.Lit] {
  let out : Array[@lib.Lit] = []
  let mut acc = 0
  let mut has_digit = false
  let mut neg = false
  for c in text {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      acc = acc * 10 + (code - 48)
      has_digit = true
    } else if code == 45 && !has_digit {
      neg = true
    } else if has_digit {
      if acc != 0 {
        out.push(@lib.lit_new(acc - 1, neg))
      }
      acc = 0
      has_digit = false
      neg = false
    }
  }
  if has_digit && acc != 0 {
    out.push(@lib.lit_new(acc - 1, neg))
  }
  out
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
  println("  moonbit-sat core   <dimacs> <lits>     unsat core of the given assumptions")
  println("  moonbit-sat bench                      search volume on a fixed random 3-SAT ladder")
  println("  moonbit-sat bench-verify <k>           refute pigeonhole k/k-1 and check the proof in-process")
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
  } else if cmd == "core" {
    if args.length() < 4 {
      usage()
      return
    }
    try {
      let f = @lib.parse_dimacs(decode(args[2]))
      let assumptions = parse_assumptions(decode(args[3]))
      let s = @lib.Solver::new(f)
      let (sat, core) = s.solve_core(assumptions)
      if sat {
        println("s SATISFIABLE")
      } else {
        println("s UNSATISFIABLE")
        if core.length() == 0 {
          println("c core= (hard clauses alone are unsatisfiable)")
        } else {
          let mut text = ""
          for l in core {
            let v = if @lib.lit_is_neg(l) {
              -(@lib.lit_var(l) + 1)
            } else {
              @lib.lit_var(l) + 1
            }
            text = text + "\{v} "
          }
          println("c core= \{text}0")
        }
      }
    } catch {
      e => println("c error: \{e}")
    }
  } else if cmd == "bench" {
    run_bench()
  } else if cmd == "bench-verify" {
    let k = if args[2] == "6" {
      6
    } else if args[2] == "7" {
      7
    } else if args[2] == "8" {
      8
    } else if args[2] == "9" {
      9
    } else if args[2] == "10" {
      10
    } else {
      8
    }
    run_bench_verify(k)
  } else {
    usage()
  }
}
