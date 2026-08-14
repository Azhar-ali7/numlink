import 'operation.dart';

/// A daily puzzle definition. Today these are hardcoded by
/// [LocalPuzzleRepository]; production will generate them server-side (BFS
/// over the op set to guarantee solvability and honest par).
class Puzzle {
  const Puzzle({
    required this.no,
    required this.dateLabel,
    required this.start,
    required this.target,
    required this.par,
    required this.ops,
    this.cap = 999,
  });

  final int no;
  final String dateLabel;
  final int start;
  final int target;
  final int par;
  final List<Operation> ops;
  final int cap;
}
