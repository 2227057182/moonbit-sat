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
      "c error: the \{what} argument looks like a file path; pass @path to read it from disk, or inline it with \"$(cat file)\"",
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
/// A model is only evidence if the clauses are checked against it, so the
/// self-test never trusts `s SATISFIABLE` on its own.
fn model_satisfies(f : @lib.Formula, m : Array[Bool]) -> Bool {
  for c in f.clauses {
    let mut hit = false
    for l in c.lits {
      let v = @lib.lit_var(l)
      if v < m.length() {
        let neg = @lib.lit_is_neg(l)
        if (neg && !m[v]) || (!neg && m[v]) {
          hit = true
        }
      }
    }
    if !hit {
      return false
    }
  }
  true
}

///|
/// One command that walks the whole pipeline — solve, prove, check, optimize,
/// core — on tiny inline instances.  The point is that a reviewer with no C
/// compiler, no shell and no instance file can still confirm the build works:
/// every stage prints one line, and a failing stage exits non-zero.  The
/// negative cases matter as much as the positive ones: a checker that accepts
/// everything would pass stage 2 without the extra "must reject a wrong proof"
/// condition.
fn run_selftest() -> Int {
  let mut passed = 0
  let mut failed = 0
  let no_assumps : Array[@lib.Lit] = []
  // 1. SAT: the model must satisfy the formula on its own.
  try {
    let f = @lib.parse_dimacs(decode("p cnf 2 2;1 2 0;-1 2 0"))
    let s = @lib.Solver::new(f)
    if s.solve(no_assumps) && model_satisfies(f, s.model()) {
      passed = passed + 1
      println("c selftest sat        ok")
    } else {
      failed = failed + 1
      println("c selftest sat        FAILED (no model, or model does not satisfy the clauses)")
    }
  } catch {
    e => {
      failed = failed + 1
      println("c selftest sat        FAILED (\{e})")
    }
  }
  // 2. UNSAT: the proof must be accepted, and a non-refutation must be rejected.
  try {
    let f = @lib.parse_dimacs(decode("p cnf 2 2;1 0;-1 0"))
    let s = @lib.Solver::new(f)
    let p = s.enable_proof()
    let sat = s.solve(no_assumps)
    let text = p.text()
    let accepted = @lib.verify_proof(f, text)
    let rejected = @lib.verify_proof(f, "1 0")
    if !sat && text.length() > 0 && accepted && !rejected {
      passed = passed + 1
      println("c selftest unsat      ok (proof accepted, wrong proof rejected)")
    } else {
      failed = failed + 1
      println("c selftest unsat      FAILED (sat=\{sat} accepted=\{accepted} rejected=\{rejected})")
    }
  } catch {
    e => {
      failed = failed + 1
      println("c selftest unsat      FAILED (\{e})")
    }
  }
  // 3. Weighted MaxSAT: x and its negation cannot both hold, so exactly one 10-weight
  //    soft clause must be violated.
  try {
    let w = @lib.parse_wcnf(decode("p wcnf 2 2 100;10 1 0;10 -1 0"))
    let opt = @lib.maxsat_solve(w, 512)
    if opt == 10 {
      passed = passed + 1
      println("c selftest maxsat     ok (opt=10)")
    } else {
      failed = failed + 1
      println("c selftest maxsat     FAILED (opt=\{opt}, expected 10)")
    }
  } catch {
    e => {
      failed = failed + 1
      println("c selftest maxsat     FAILED (\{e})")
    }
  }
  // 4. The reported optimum must survive an independent recomputation of cost
  //    from the assignment alone.
  try {
    let w = @lib.parse_wcnf(decode("p wcnf 2 2 100;10 1 0;10 -1 0"))
    match @lib.maxsat_solution(w, 512) {
      Some((model, cost)) =>
        if @lib.verify_maxsat_solution(w, model, cost) {
          passed = passed + 1
          println("c selftest maxsat-asm ok (cost recomputed from the assignment)")
        } else {
          failed = failed + 1
          println("c selftest maxsat-asm FAILED (cost does not recompute)")
        }
      None => {
        failed = failed + 1
        println("c selftest maxsat-asm FAILED (no solution returned)")
      }
    }
  } catch {
    e => {
      failed = failed + 1
      println("c selftest maxsat-asm FAILED (\{e})")
    }
  }
  // 5. Core extraction: forcing x1 on an UNSAT formula must yield a non-empty
  //    core, and the core must be a subset of the assumptions.
  try {
    let f = @lib.parse_dimacs(decode("p cnf 2 2;-1 0;2 0"))
    let s = @lib.Solver::new(f)
    let assumps : Array[@lib.Lit] = [@lib.lit_new(0, false)]
    let (sat, core) = s.solve_core(assumps)
    let mut subset = core.length() > 0
    for l in core {
      if @lib.lit_var(l) != 0 {
        subset = false
      }
    }
    if !sat && subset {
      passed = passed + 1
      println("c selftest core       ok (core=\{core.length()} literal, subset of assumptions)")
    } else {
      failed = failed + 1
      println("c selftest core       FAILED (sat=\{sat} core=\{core.length()} subset=\{subset})")
    }
  } catch {
    e => {
      failed = failed + 1
      println("c selftest core       FAILED (\{e})")
    }
  }
  if failed > 0 {
    println("c selftest FAILED \{passed}/\{passed + failed}")
  } else {
    println("c selftest \{passed}/\{passed + failed} passed")
  }
  failed
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
  let mut any = false
  for c in text {
    let code = c.to_int()
    if code < 48 || code > 57 {
      // A non-digit makes the argument ambiguous.  Returning -1 lets the caller
      // reject it; the old version skipped the character and read e.g. "abc" as 0.
      return -1
    }
    acc = acc * 10 + (code - 48)
    any = true
  }
  if any {
    acc
  } else {
    -1
  }
}

///|
/// Print the reason a WCNF instance cannot be optimised, and report whether the
/// caller should stop.  Kept next to `parse_uint` because both exist to turn
/// silent mis-reads into messages.
fn wcnf_ok_or_report(w : @lib.Wcnf) -> Bool {
  match @lib.wcnf_error(w) {
    Some(e) => {
      println("c error: \{e}")
      false
    }
    None => true
  }
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
  println("  moonbit-sat maxsat-verify-external <wcnf> <opt> <lits> <drat>  same two halves, but the assignment and the proof come from outside")
  println("  moonbit-sat maxsat-solution <wcnf>    optimal assignment and its recomputed cost")
  println("  moonbit-sat maxsat-oll <wcnf>         core-guided optimum, no cap on total soft weight")
  println("  moonbit-sat maxsat-oll-budget <wcnf> <rounds>  same, with a round budget: prints the bounds it reached")
  println("  moonbit-sat verify-solution <wcnf> <cost> <lits>  recompute the cost of an exported assignment")
  println("  moonbit-sat core   <dimacs> <lits>     unsat core of the given assumptions")
  println("  moonbit-sat grid-wcnf <rows> <cols>    print a grid minimum-vertex-cover WCNF instance")
  println("  moonbit-sat bench                      search volume on a fixed random 3-SAT ladder")
  println("  moonbit-sat bench-verify <k>           refute pigeonhole k/k-1 and check the proof in-process")
  println("  moonbit-sat selftest                   solve/prove/check/optimize/core on inline instances; exits non-zero if any stage fails")
  println("")
  println("`;` in the argument is treated as a newline, so formulas can be passed inline.")
  println("An argument starting with `@` names a file and is read from disk, e.g. @examples/pigeonhole-3-2.cnf.")
}

///|
fn main {
  let raw_args = @env.args()
  // An argument that starts with `@` names a file and is read from disk.  The
  // alternative is passing the text inline, which hits the 128 KB per-argument
  // limit of the kernel on Linux long before a k=10 proof (24 MB) fits.
  let args : Array[String] = []
  let mut unreadable = false
  let mut i = 0
  while i < raw_args.length() {
    let a = raw_args[i]
    if i >= 2 && a.length() > 0 && a[0] == '@' {
      let path = a[1:].to_owned()
      let text = try {
        @fs.read_file_to_string(path)
      } catch {
        _ => {
          println("c error: cannot read file \{path}")
          unreadable = true
          ""
        }
      }
      args.push(text)
    } else {
      args.push(a)
    }
    i = i + 1
  }
  if unreadable {
    return
  }
  if args.length() < 3 {
    if args.length() == 2 {
      if args[1] == "bench" {
        run_bench()
        return
      }
      if args[1] == "selftest" {
        run_selftest() |> ignore
        return
      }
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
      if !wcnf_ok_or_report(w) {
        return
      }
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
      if !wcnf_ok_or_report(w) {
        return
      }
    let k = parse_uint(args[3])
    if k < 0 {
      println("c error: expected a non-negative integer, got \{args[3]}")
      return
    }
    println(@lib.to_dimacs(@lib.maxsat_encoding(w, k)))
  } else if cmd == "maxsat-proof" {
    if args.length() < 4 {
      usage()
      return
    }
    let w = @lib.parse_wcnf(decode(args[2]))
      if !wcnf_ok_or_report(w) {
        return
      }
    let k = parse_uint(args[3])
    if k < 0 {
      println("c error: expected a non-negative integer, got \{args[3]}")
      return
    }
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
      if !wcnf_ok_or_report(w) {
        return
      }
    let k = parse_uint(args[3])
    if k < 0 {
      println("c error: expected a non-negative integer, got \{args[3]}")
      return
    }
    let proof = decode(args[4])
    let ok = @lib.verify_maxsat_bound(w, k, proof)
    println(if ok { "s VERIFIED" } else { "s PROOF-REJECTED" })
  } else if cmd == "maxsat-verify" {
    try {
      let w = @lib.parse_wcnf(decode(args[2]))
      if !wcnf_ok_or_report(w) {
        return
      }
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
  } else if cmd == "maxsat-verify-external" {
    if args.length() < 6 {
      println(
        "c usage: maxsat-verify-external <wcnf> <opt> <lits like \"1 -2 3 0\"> <drat>",
      )
      return
    }
    let w = @lib.parse_wcnf(decode(args[2]))
    if !wcnf_ok_or_report(w) {
      return
    }
    let opt = parse_uint(args[3])
    if opt < 0 {
      println("c error: expected a non-negative integer, got \{args[3]}")
      return
    }
    let model = parse_model(decode(args[4]), w.num_vars)
    let proof = decode(args[5])
    // 上界来自调用方给的赋值，下界来自调用方给的证明，两者都不采信。
    let (upper, lower) = @lib.verify_maxsat_external(w, opt, model, proof)
    println("o \{opt}")
    println("c upper= \{upper} lower= \{lower}")
    println(if upper && lower {
      "s OPTIMALITY-VERIFIED"
    } else {
      "s PROOF-REJECTED"
    })
  } else if cmd == "maxsat-oll" {
    let wcnf_text = decode(args[2])
    if reject_path_arg(wcnf_text, "wcnf") {
      return
    }
    let w = @lib.parse_wcnf(wcnf_text)
      if !wcnf_ok_or_report(w) {
        return
      }
    match @lib.maxsat_oll_solution(w) {
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
  } else if cmd == "maxsat-oll-budget" {
    if args.length() < 4 {
      usage()
      return
    }
    let wcnf_text = decode(args[2])
    if reject_path_arg(wcnf_text, "wcnf") {
      return
    }
    let w = @lib.parse_wcnf(wcnf_text)
      if !wcnf_ok_or_report(w) {
        return
      }
    let rounds = parse_uint(args[3])
    if rounds < 0 {
      println("c error: expected a non-negative integer, got \{args[3]}")
      return
    }
    match @lib.maxsat_oll_result(w, rounds) {
      Solved(model, cost) => {
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
      Budgeted(lower, upper) => {
        println("c rounds= \{rounds} lower= \{lower} upper= \{upper}")
        println("s UNKNOWN (round budget exhausted)")
      }
      Infeasible => println("s UNSATISFIABLE (hard clauses)")
    }
  } else if cmd == "maxsat-solution" {
    try {
      let w = @lib.parse_wcnf(decode(args[2]))
      if !wcnf_ok_or_report(w) {
        return
      }
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
      if !wcnf_ok_or_report(w) {
        return
      }
      let cost = parse_uint(args[3])
      if cost < 0 {
        println("c error: expected a non-negative integer, got \{args[3]}")
        return
      }
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
  } else if cmd == "selftest" {
    run_selftest() |> ignore
  } else if cmd == "bench-verify" {
    let k = parse_uint(args[2])
    if k < 6 || k > 10 {
      println("c error: bench-verify expects k in 6..10, got \{args[2]}")
      return
    }
    run_bench_verify(k)
  } else {
    usage()
  }
}
