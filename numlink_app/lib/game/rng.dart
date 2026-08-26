/// Deterministic MINSTD (Park–Miller) PRNG, ported verbatim from the NUMLINK
/// prototype so daily and co-op boards reproduce identically across platforms.
typedef Rng = double Function();

/// Returns a generator yielding doubles in `[0, 1)` from [seed].
Rng minstd(int seed) {
  var s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () {
    s = (s * 16807) % 2147483647;
    return s / 2147483647;
  };
}

/// Fisher–Yates in-place shuffle driven by [rnd].
///
/// Deliberately NOT a comparator/`sort`-based shuffle: that calls the RNG an
/// engine-dependent number of times and would desync the seeded stream,
/// breaking cross-platform daily reproducibility.
void shuffleInPlace<T>(List<T> list, Rng rnd) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = (rnd() * (i + 1)).floor();
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
  }
}
