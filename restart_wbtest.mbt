///|
/// The Luby sequence is the contract between the restart schedule and the
/// search: off-by-one here silently changes restart frequency without failing
/// any correctness test, so the first terms are pinned explicitly.
test "luby sequence matches the first sixteen terms" {
  let expected : Array[Int] = [1, 1, 2, 1, 1, 2, 4, 1, 1, 2, 1, 1, 2, 4, 8, 1]
  let mut i = 1
  while i <= expected.length() {
    assert_eq(luby(i), expected[i - 1])
    i = i + 1
  }
}

///|
test "luby sequence is positive and bounded by powers of two" {
  let mut i = 1
  while i <= 64 {
    let v = luby(i)
    assert_true(v >= 1)
    assert_true(v <= 64)
    i = i + 1
  }
}

///|
test "luby sequence never exceeds the next power of two above its index" {
  let mut i = 1
  while i <= 32 {
    let v = luby(i)
    assert_true(v <= i)
    i = i + 1
  }
}
