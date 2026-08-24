import 'campaign.dart';

/// Daily-puzzle identity (number + human date), shown on the Home hub and the
/// settings credits. The board content itself comes from the branching engine
/// (`dailyBranchingPuzzle`); this only supplies the calendar metadata.
class DailyInfo {
  const DailyInfo(this.no, this.dateLabel);
  final int no;
  final String dateLabel;
}

/// Date math for the daily/archive schedule and the campaign length. Anchored
/// so #128 lands on 2026-08-08 (the handoff daily). No puzzle generation lives
/// here any more — the branching engine owns board content.
class PuzzleCalendar {
  const PuzzleCalendar();

  static final DateTime _epoch = DateTime.utc(2026, 8, 8);
  static const int _epochNo = 128;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  int _numberFor(DateTime date) =>
      _dateOnly(date).difference(_epoch).inDays + _epochNo;

  String _labelFor(DateTime date) =>
      '${_months[date.month - 1]} ${date.day} ${date.year}';

  /// Today's daily identity.
  DailyInfo today() {
    final now = DateTime.now();
    return DailyInfo(_numberFor(now), _labelFor(now));
  }

  /// Past daily numbers available to replay, newest first, excluding today.
  List<int> archiveNumbers() {
    final todayNo = _numberFor(DateTime.now());
    return [for (var n = todayNo - 1; n >= _epochNo; n--) n];
  }

  /// Number of levels in the campaign.
  int get campaignCount => kCampaign.length;
}
