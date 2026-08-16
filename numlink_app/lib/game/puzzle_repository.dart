import '../models/puzzle.dart';
import 'campaign.dart';
import 'game_mode.dart';
import 'generator.dart';

/// Source of puzzles. Swap [LocalPuzzleRepository] for a remote impl later
/// without touching the game controller.
abstract class PuzzleRepository {
  /// Today's shared daily puzzle.
  Future<Puzzle> today();

  /// The deterministic daily puzzle for [date] — identical for everyone.
  Future<Puzzle> daily(DateTime date);

  /// A fresh puzzle at tier [d]. Deterministic when [seed] is given.
  Future<Puzzle> generate(Difficulty d, {int? seed});

  /// Reproduce a past daily by its number.
  Future<Puzzle> archive(int puzzleNo);

  /// Past daily numbers available to replay, newest first, excluding today.
  List<int> archiveNumbers();

  /// An escalating sequence of [count] puzzles for the timed ladder,
  /// deterministic in [runSeed].
  List<Puzzle> ladder(int count, {required int runSeed});

  /// The curated campaign level [levelNo] (1-based), deterministic for everyone.
  Future<Puzzle> campaign(int levelNo);

  /// Number of levels in the campaign.
  int get campaignCount;
}

/// On-device puzzles via [PuzzleGenerator]. Daily/archive are seeded by date/
/// number so they're reproducible and identical for every player.
class LocalPuzzleRepository implements PuzzleRepository {
  const LocalPuzzleRepository();

  static const _gen = PuzzleGenerator();

  /// Launch epoch anchored so #128 lands on 2026-08-08 (the handoff daily).
  static final DateTime _epoch = DateTime.utc(2026, 8, 8);
  static const int _epochNo = 128;

  /// Fixed daily tier (no weekday ramp — see the locked difficulty-UX decision).
  static const Difficulty _dailyTier = Difficulty.medium;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  int _numberFor(DateTime date) =>
      _dateOnly(date).difference(_epoch).inDays + _epochNo;

  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  String _labelFor(DateTime date) =>
      '${_months[date.month - 1]} ${date.day} ${date.year}';

  DateTime _dateForNumber(int no) =>
      _epoch.add(Duration(days: no - _epochNo));

  @override
  Future<Puzzle> today() => daily(DateTime.now());

  @override
  Future<Puzzle> daily(DateTime date) async {
    final no = _numberFor(date);
    return _gen.generate(
      _dailyTier,
      no: no,
      dateLabel: _labelFor(date),
      seed: no, // same number → same puzzle for everyone
    );
  }

  @override
  Future<Puzzle> generate(Difficulty d, {int? seed}) async =>
      _gen.generate(d, seed: seed);

  @override
  Future<Puzzle> archive(int puzzleNo) async {
    final date = _dateForNumber(puzzleNo);
    return _gen.generate(
      _dailyTier,
      no: puzzleNo,
      dateLabel: _labelFor(date),
      seed: puzzleNo,
    );
  }

  @override
  List<int> archiveNumbers() {
    final todayNo = _numberFor(DateTime.now());
    return [for (var n = todayNo - 1; n >= _epochNo; n--) n];
  }

  @override
  int get campaignCount => kCampaign.length;

  @override
  Future<Puzzle> campaign(int levelNo) async {
    final def = kCampaign[levelNo - 1];
    return _gen.generate(def.tier, no: def.no, seed: def.seed);
  }

  @override
  List<Puzzle> ladder(int count, {required int runSeed}) {
    // Escalate easy → medium → hard, cycling on hard for long runs.
    const ramp = [
      Difficulty.easy,
      Difficulty.easy,
      Difficulty.medium,
      Difficulty.medium,
      Difficulty.hard,
    ];
    return [
      for (var i = 0; i < count; i++)
        _gen.generate(
          ramp[i < ramp.length ? i : ramp.length - 1],
          no: i + 1,
          seed: runSeed * 1000 + i,
        ),
    ];
  }
}
