///|
/// Literal encoding used throughout the solver.
///
/// A literal is stored as `2 * variable + sign`, where `sign` is 0 for a
/// positive literal and 1 for a negated one.  The variable keeps a dense
/// 0-based index, which lets the solver use plain integer arrays for all
/// per-variable state.
pub type Lit = Int

///|
/// Build a literal from a variable and a sign flag.
pub fn lit_new(v : Int, neg : Bool) -> Lit {
  if neg {
    v * 2 + 1
  } else {
    v * 2
  }
}

///|
/// Variable index of a literal.
pub fn lit_var(l : Lit) -> Int {
  l / 2
}

///|
/// Whether the literal is negated.
pub fn lit_is_neg(l : Lit) -> Bool {
  l % 2 == 1
}

///|
/// Complement of a literal.  `lit_neg(lit_neg(l)) == l`.
pub fn lit_neg(l : Lit) -> Lit {
  if l < 0 {
    abort("lit_neg expects a non-negative literal")
  }
  if l % 2 == 1 {
    l - 1
  } else {
    l + 1
  }
}
