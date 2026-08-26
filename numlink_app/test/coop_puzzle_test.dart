import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/screens/tree_game_page.dart';

void main() {
  test('weekendCoopPuzzle is stable within an ISO week, differs across weeks', () {
    // Mon..Sun of one week → identical board (same start + targets).
    final mon = weekendCoopPuzzle(DateTime(2026, 8, 24));
    final sun = weekendCoopPuzzle(DateTime(2026, 8, 30));
    expect(sun.start, mon.start);
    expect(sun.targets, mon.targets);

    // The following Monday rolls to a different board.
    final nextMon = weekendCoopPuzzle(DateTime(2026, 8, 31));
    expect(
      nextMon.start != mon.start || !_sameList(nextMon.targets, mon.targets),
      isTrue,
      reason: 'a new week must seed a new board',
    );
  });
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
