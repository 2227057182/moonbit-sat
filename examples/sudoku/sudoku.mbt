///|
/// 数独 → CNF：一个真实场景，用来证明这个库不只「能解随机 3-SAT」。
///
/// 变量（1 基）：v(r, c, d) = r*81 + c*9 + d + 1，表示第 r 行第 c 列填 d+1。
/// 四类约束，共 11745 条（不含提示）：
///   每格至少一个数字          81 条 9 文字子句
///   每格至多一个数字          81 * C(9,2) = 2916 条二元子句
///   每行 / 每列 / 每宫各一次   3 * 9 * 9 * C(9,2) = 8748 条二元子句
/// 提示格写成单元子句。求解后按行、列、宫逐条复核——解不是「求解器说对就对」。

///|
fn var_of(r : Int, c : Int, d : Int) -> Int {
  r * 81 + c * 9 + d + 1
}

///|
/// 两个位置不能同时取值：写成 ¬a ∨ ¬b。
fn pair(f : @lib.Formula, a : Int, b : Int) -> Unit {
  f.add([@lib.lit_new(a - 1, true), @lib.lit_new(b - 1, true)]) |> ignore
}

///|
fn encode(puzzle : Array[Int]) -> @lib.Formula {
  let f = @lib.Formula::new(729)
  // 1. 每格至少一个数字
  let mut r = 0
  while r < 9 {
    let mut c = 0
    while c < 9 {
      let cells : Array[@lib.Lit] = []
      let mut d = 0
      while d < 9 {
        cells.push(@lib.lit_new(var_of(r, c, d) - 1, false))
        d = d + 1
      }
      f.add(cells) |> ignore
      c = c + 1
    }
    r = r + 1
  }
  // 2. 每格至多一个数字
  r = 0
  while r < 9 {
    let mut c = 0
    while c < 9 {
      let mut d1 = 0
      while d1 < 9 {
        let mut d2 = d1 + 1
        while d2 < 9 {
          pair(f, var_of(r, c, d1), var_of(r, c, d2))
          d2 = d2 + 1
        }
        d1 = d1 + 1
      }
      c = c + 1
    }
    r = r + 1
  }
  // 3a. 每行的同一数字只能出现一次
  let mut d = 0
  while d < 9 {
    r = 0
    while r < 9 {
      let mut c1 = 0
      while c1 < 9 {
        let mut c2 = c1 + 1
        while c2 < 9 {
          pair(f, var_of(r, c1, d), var_of(r, c2, d))
          c2 = c2 + 1
        }
        c1 = c1 + 1
      }
      r = r + 1
    }
    d = d + 1
  }
  // 3b. 每列的同一数字只能出现一次
  d = 0
  while d < 9 {
    let mut c = 0
    while c < 9 {
      let mut r1 = 0
      while r1 < 9 {
        let mut r2 = r1 + 1
        while r2 < 9 {
          pair(f, var_of(r1, c, d), var_of(r2, c, d))
          r2 = r2 + 1
        }
        r1 = r1 + 1
      }
      c = c + 1
    }
    d = d + 1
  }
  // 3c. 每宫的同一数字只能出现一次
  d = 0
  while d < 9 {
    let mut b = 0
    while b < 9 {
      let r0 = (b / 3) * 3
      let c0 = (b % 3) * 3
      let mut k1 = 0
      while k1 < 9 {
        let mut k2 = k1 + 1
        while k2 < 9 {
          let r1 = r0 + k1 / 3
          let c1 = c0 + k1 % 3
          let r2 = r0 + k2 / 3
          let c2 = c0 + k2 % 3
          pair(f, var_of(r1, c1, d), var_of(r2, c2, d))
          k2 = k2 + 1
        }
        k1 = k1 + 1
      }
      b = b + 1
    }
    d = d + 1
  }
  // 4. 提示
  let mut i = 0
  while i < 81 {
    if puzzle[i] > 0 {
      f.add([@lib.lit_new(var_of(i / 9, i % 9, puzzle[i] - 1) - 1, false)])
      |> ignore
    }
    i = i + 1
  }
  f
}

///|
fn read_grid(model : Array[Bool]) -> Array[Int] {
  let grid : Array[Int] = []
  let mut r = 0
  while r < 9 {
    let mut c = 0
    while c < 9 {
      let mut value = 0
      let mut d = 0
      while d < 9 {
        if model[var_of(r, c, d) - 1] {
          value = d + 1
        }
        d = d + 1
      }
      grid.push(value)
      c = c + 1
    }
    r = r + 1
  }
  grid
}

///|
/// 独立复核：每格 1-9、每行/列/宫各数字恰好一次、与提示一致。
/// 这段不碰求解器内部状态，只看填出来的 81 个数。
fn check(grid : Array[Int], puzzle : Array[Int]) -> Bool {
  if grid.length() != 81 {
    return false
  }
  let mut i = 0
  while i < 81 {
    if grid[i] < 1 || grid[i] > 9 {
      return false
    }
    if puzzle[i] > 0 && puzzle[i] != grid[i] {
      return false
    }
    i = i + 1
  }
  // 行、列各 9 组，宫 9 组，共 27 组
  let mut unit = 0
  while unit < 27 {
    let counts : Array[Int] = Array::make(10, 0)
    let mut k = 0
    while k < 9 {
      let idx = if unit < 9 {
        unit * 9 + k
      } else if unit < 18 {
        k * 9 + (unit - 9)
      } else {
        let b = unit - 18
        ((b / 3) * 3 + k / 3) * 9 + (b % 3) * 3 + k % 3
      }
      counts[grid[idx]] = counts[grid[idx]] + 1
      k = k + 1
    }
    let mut v = 1
    while v <= 9 {
      if counts[v] != 1 {
        return false
      }
      v = v + 1
    }
    unit = unit + 1
  }
  true
}

///|
fn parse_puzzle(text : String) -> Array[Int] {
  let cells : Array[Int] = []
  for ch in text {
    if ch >= '1' && ch <= '9' {
      cells.push(ch.to_int() - '1'.to_int() + 1)
    } else if ch == '.' || ch == '0' {
      cells.push(0)
    }
  }
  cells
}

///|
fn show(grid : Array[Int]) -> Unit {
  let mut r = 0
  while r < 9 {
    if r % 3 == 0 {
      println("+-------+-------+-------+")
    }
    let mut line = "|"
    let mut c = 0
    while c < 9 {
      if c % 3 == 0 {
        line = line + " "
      }
      line = line + grid[r * 9 + c].to_string() + " "
      c = c + 1
    }
    println(line + "|")
    r = r + 1
  }
  println("+-------+-------+-------+")
}

///|
/// AI Escargot，公开报道里被称作最难的一类数独：提示少、需要真实回溯。
let default_puzzle : String =
  "1....7.9..3..2...8..96..5....53..9...1..8...26....4...3......1..4......7..7...3.."

///|
fn count_lines(text : String) -> Int {
  let mut n = 1
  for ch in text {
    if ch == '\n' {
      n = n + 1
    }
  }
  n
}

///|
fn main {
  let args = @env.args()
  let text = if args.length() > 1 {
    args[1]
  } else {
    default_puzzle
  }
  let puzzle = parse_puzzle(text)
  if puzzle.length() != 81 {
    println("c error: need 81 cells, got \{puzzle.length()}")
    return
  }
  let f = encode(puzzle)
  println("c vars=729 clauses=\{f.num_clauses()}")
  let s = @lib.Solver::new(f)
  // 证明记录全程打开：SAT 时只是多记几条学习子句，UNSAT 时给出可独立复算的 DRAT。
  // 这是给「可校验」做演示——同一套编码，换一道矛盾题就得到一份能被验证的证明。
  let p = s.enable_proof()
  if !s.solve([]) {
    println("s UNSATISFIABLE")
    println("c \{s.stats_string()}")
    let proof = p.text()
    println("c proof lines=\{count_lines(proof)}")
    println("c proof self-check=\{@lib.verify_proof(f, proof)}")
    return
  }
  let grid = read_grid(s.model())
  println("s SATISFIABLE")
  show(grid)
  println("c \{s.stats_string()}")
  println("c verified=\{check(grid, puzzle)}")
}
