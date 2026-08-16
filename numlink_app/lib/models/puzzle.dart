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
    this.solution = const [],
  });

  final int no;
  final String dateLabel;
  final int start;
  final int target;
  final int par;
  final List<Operation> ops;
  final int cap;

  /// The op-id sequence of one shortest solution (the definite answer path),
  /// produced by the generator in the same BFS pass that fixes [par]. Length
  /// equals [par]. Empty only for legacy/hardcoded puzzles.
  final List<String> solution;

  Map<String, dynamic> toJson() => {
        'no': no,
        'dateLabel': dateLabel,
        'start': start,
        'target': target,
        'par': par,
        'ops': ops.map((o) => o.toJson()).toList(),
        'cap': cap,
        'solution': solution,
      };

  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
        no: j['no'] as int,
        dateLabel: j['dateLabel'] as String,
        start: j['start'] as int,
        target: j['target'] as int,
        par: j['par'] as int,
        ops: (j['ops'] as List)
            .map((e) => Operation.fromJson(e as Map<String, dynamic>))
            .toList(),
        cap: j['cap'] as int? ?? 999,
        solution:
            (j['solution'] as List?)?.map((e) => e as String).toList() ??
                const [],
      );
}
