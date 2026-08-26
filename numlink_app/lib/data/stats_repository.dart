import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_stats.dart';

/// Persistence seam for player stats. [LocalStatsRepository] stores on-device;
/// a future [RemoteStatsRepository] implements the same interface for
/// account-based cloud sync — no controller/UI changes required.
abstract class StatsRepository {
  Future<GameStats> load();
  Future<void> save(GameStats stats);
}

class LocalStatsRepository implements StatsRepository {
  LocalStatsRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'numlink_stats';

  @override
  Future<GameStats> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return GameStats.empty; // a new player has played nothing
    try {
      return GameStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return GameStats.empty;
    }
  }

  @override
  Future<void> save(GameStats stats) async {
    await _prefs.setString(_key, jsonEncode(stats.toJson()));
  }
}
