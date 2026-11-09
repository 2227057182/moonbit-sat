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
fn usage() -> Unit {
  println("moonbit-sat — CDCL SAT / MaxSAT toolkit")
  println("")
  println("usage:")
  println("  moonbit-sat solve  <dimacs>            solve a CNF, print SAT/UNSAT, model and stats")
  println("  moonbit-sat proof  <dimacs>            solve and print a DRAT proof when UNSAT")
  println("  moonbit-sat verify <dimacs> <proof>    independently check a DRAT proof")
  println("  moonbit-sat maxsat <wcnf>              optimal weighted MaxSAT cost")
  println("")
  println("`;` in the argument is treated as a newline, so formulas can be passed inline.")
}

///|
fn main {
  let args = @env.args()
  if args.length() < 3 {
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
  } else if cmd == "verify" {
    if args.length() < 4 {
      usage()
      return
    }
    try {
      let f = @lib.parse_dimacs(decode(args[2]))
      let ok = @lib.verify_proof(f, decode(args[3]))
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
  } else {
    usage()
  }
}
