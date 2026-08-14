import '../models/operation.dart';
import '../models/puzzle.dart';

/// Source of daily puzzles. Swap [LocalPuzzleRepository] for a remote impl
/// later without touching the game controller.
abstract class PuzzleRepository {
  Future<Puzzle> today();
}

/// Hardcoded puzzle #128, matching the design prototype exactly.
/// Par-3 solution: 2 ×3→6 +7→13 ×2→26.
class LocalPuzzleRepository implements PuzzleRepository {
  const LocalPuzzleRepository();

  @override
  Future<Puzzle> today() async => const Puzzle(
        no: 128,
        dateLabel: 'AUG 8 2026',
        start: 2,
        target: 26,
        par: 3,
        ops: [
          Operation(id: 'm3', symbol: '×', n: 3, tokens: 2),
          Operation(id: 'p7', symbol: '+', n: 7, tokens: 2),
          Operation(id: 'm2', symbol: '×', n: 2, tokens: 3),
          Operation(id: 's1', symbol: '−', n: 1, tokens: 3),
          Operation(id: 'd2', symbol: '÷', n: 2, tokens: 2),
          Operation(id: 'p5', symbol: '+', n: 5, tokens: 2),
        ],
      );
}
