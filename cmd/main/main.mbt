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
/// The CLI takes formulas inline.  A pasted file path would otherwise be
/// scanned for integers and turned into some unrelated small formula, which
/// then gets reported as `s SATISFIABLE` — for a solver that is the worst
/// possible failure mode.  MoonBit core has no file system module, so this
/// rejects the argument instead of silently mis-reading it.
fn reject_path_arg(text : String, what : String) -> Bool {
  if text.contains("p cnf") || text.contains("p wcnf") {
    return false
  }
  if text.contains("/") || text.contains("\\") || text.contains(".cnf") || text.contains(".wcnf") {
    println(
      "c error: the \{what} argument looks like a file path; formulas are passed inline, so expand it first with \"$(cat file)\"",
    )
    return true
  }
  false
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
fn parse_uint(text : String) -> Int {
  let mut acc = 0
  for c in text {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      acc = acc * 10 + (code - 48)
    }
  }
  acc
}

///|
/// Read a literal list ("v 1 -2 3 0") into a full assignment.  Unknown variables
/// stay false, which is what a checker must assume for anything not claimed.
fn parse_model(text : String, num_vars : Int) -> Array[Bool] {
  let model : Array[Bool] = []
  let mut i = 0
  while i < num_vars {
    model.push(false)
    i = i + 1
  }
  for token in text.split(" ") {
    let s = token.to_owned()
    if s == "" || s == "v" || s == "0" {
      continue
    }
    let neg = match s.get_char(0) {
      Some('-') => true
      _ => false
    }
    let start = if neg { 1 } else { 0 }
    let mut acc = 0
    let mut j = start
    while j < s.length() {
      match s.get_char(j) {
        Some(d) => {
          let code = d.to_int()
          if code >= 48 && code <= 57 {
            acc = acc * 10 + (code - 48)
          }
        }
        None => ()
      }
      j = j + 1
    }
    let v = if acc > 0 {
      if neg {
        -acc
      } else {
        acc
      }
    } else {
      0
    }
    if v != 0 {
      let idx = if v > 0 { v - 1 } else { -v - 1 }
      if idx < num_vars {
        model[idx] = v > 0
      }
    }
  }
  model
}

///|
/// Render a grid minimum-vertex-cover WCNF instance: one hard clause (u v) per
/// edge, one soft clause (-v) of weight 1 per vertex.  A grid is bipartite, so
/// the optimum equals the maximum matching size.
fn grid_wcnf_text(rows : Int, cols : Int) -> String {
  let nverts = rows * cols
  let nedges = (rows - 1) * cols + rows * (cols - 1)
  let mut text = "c grid minimum vertex cover: hard (u v) per edge, soft (-v) weight 1 per vertex\n"
  text = text + "p wcnf \{nverts} \{nedges + nverts} 2\n"
  let mut r = 0
  while r < rows {
    let mut c = 0
    while c < cols {
      let v = r * cols + c + 1
      if c + 1 < cols {
        text = text + "2 \{v} \{v + 1} 0\n"
      }
      if r + 1 < rows {
        text = text + "2 \{v} \{v + cols} 0\n"
      }
      c = c + 1
    }
    r = r + 1
  }
  let mut v = 1
  while v <= nverts {
    text = text + "1 -\{v} 0\n"
    v = v + 1
  }
  text
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
  println("  moonbit-sat maxsat-cnf <wcnf> <k>     the CNF that decides cost <= k, for external checkers")
  println("  moonbit-sat maxsat-proof <wcnf> <k>   DRAT proof that cost <= k is unreachable")
  println("  moonbit-sat verify-maxsat <wcnf> <k> <proof>  re-check a lower-bound proof")
  println("  moonbit-sat maxsat-verify <wcnf>      check both halves of the optimum: a matching assignment and the refutation of opt-1")
  println("  moonbit-sat maxsat-solution <wcnf>    optimal assignment and its recomputed cost")
  println("  moonbit-sat verify-solution <wcnf> <cost> <lits>  recompute the cost of an exported assignment")
  println("  moonbit-sat core   <dimacs> <lits>     unsat core of the given assumptions")
  println("  moonbit-sat grid-wcnf <rows> <cols>    print a grid minimum-vertex-cover WCNF instance")
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
      if reject_path_arg(text, "formula") {
        return
      }
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
      let text = decode(args[2])
      if reject_path_arg(text, "formula") {
        return
      }
      let f = @lib.parse_dimacs(text)
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
      let wcnf_text = decode(args[2])
      if reject_path_arg(wcnf_text, "wcnf") {
        return
      }
      let w = @lib.parse_wcnf(wcnf_text)
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
  } else if cmd == "maxsat-cnf" {
    if args.length() < 4 {
      usage()
      return
    }
    let wcnf_text = decode(args[2])
    if reject_path_arg(wcnf_text, "wcnf") {
      return
    }
    let w = @lib.parse_wcnf(wcnf_text)
    let k = parse_uint(args[3])
    println(@lib.to_dimacs(@lib.maxsat_encoding(w, k)))
  } else if cmd == "maxsat-proof" {
    if args.length() < 4 {
      usage()
      return
    }
    let w = @lib.parse_wcnf(decode(args[2]))
    let k = parse_uint(args[3])
    match @lib.maxsat_bound_proof(w, k) {
      Some(p) => {
        println("s UNSATISFIABLE (cost <= \{k} unreachable)")
        println(p)
      }
      None => println("s SATISFIABLE (cost <= \{k} achievable)")
    }
  } else if cmd == "verify-maxsat" {
    if args.length() < 5 {
      usage()
      return
    }
    let w = @lib.parse_wcnf(decode(args[2]))
    let k = parse_uint(args[3])
    let proof = decode(args[4])
    let ok = @lib.verify_maxsat_bound(w, k, proof)
    println(if ok { "s VERIFIED" } else { "s PROOF-REJECTED" })
  } else if cmd == "maxsat-verify" {
    try {
      let w = @lib.parse_wcnf(decode(args[2]))
      let opt = @lib.maxsat_solve(w, 512)
      if opt < 0 {
        println("s UNSATISFIABLE (hard clauses)")
      } else {
        // 上界：一个真的达到 opt 的赋值；下界：opt-1 不可达的证明。
        let upper = match @lib.maxsat_solution(w, 512) {
          Some((m, c)) => c == opt && @lib.verify_maxsat_solution(w, m, opt)
          None => false
        }
        let lower = if opt == 0 {
          true
        } else {
          match @lib.maxsat_bound_proof(w, opt - 1) {
            Some(p) => @lib.verify_maxsat_bound(w, opt - 1, p)
            None => false
          }
        }
        println("o \{opt}")
        println("c upper= \{upper} lower= \{lower}")
        println(if upper && lower {
          "s OPTIMALITY-VERIFIED"
        } else {
          "s PROOF-REJECTED"
        })
      }
    } catch {
      e => println("c error: \{e}")
    }
  } else if cmd == "maxsat-solution" {
    try {
      let w = @lib.parse_wcnf(decode(args[2]))
      match @lib.maxsat_solution(w, 512) {
        Some((model, cost)) => {
          let mut text = ""
          let mut i = 0
          while i < model.length() {
            text = text + (if model[i] { "\{i + 1} " } else { "-\{i + 1} " })
            i = i + 1
          }
          println("o \{cost}")
          println("v \{text}0")
          println(if @lib.verify_maxsat_solution(w, model, cost) {
            "s SOLUTION-VERIFIED"
          } else {
            "s SOLUTION-REJECTED"
          })
        }
        None => println("s UNSATISFIABLE (hard clauses)")
      }
    } catch {
      e => println("c error: \{e}")
    }
  } else if cmd == "verify-solution" {
    if args.length() < 5 {
      println("c usage: verify-solution <wcnf> <cost> <lits like \"1 -2 3 0\">")
    } else {
      let w = @lib.parse_wcnf(decode(args[2]))
      let cost = parse_uint(args[3])
      let model = parse_model(decode(args[4]), w.num_vars)
      println(if @lib.verify_maxsat_solution(w, model, cost) {
        "s SOLUTION-VERIFIED"
      } else {
        "s SOLUTION-REJECTED"
      })
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
  } else if cmd == "grid-wcnf" {
    if args.length() < 4 {
      usage()
      return
    }
    let rows = parse_uint(args[2])
    let cols = parse_uint(args[3])
    if rows < 2 || cols < 2 {
      println("c error: rows and cols must be at least 2")
      return
    }
    println(grid_wcnf_text(rows, cols))
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
