import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    } catch (e) {
      // Park the unreadable blob under its own key first: returning empty
      // alone meant the next save() overwrote it, so one bad decode silently
      // erased the player's streak, distribution, stars and XP for good.
      debugPrint('stats decode failed, quarantined to $_key.bad: $e');
      await _prefs.setString('$_key.bad', raw);
      return GameStats.empty;
    }
  }

  @override
  Future<void> save(GameStats stats) async {
    await _prefs.setString(_key, jsonEncode(stats.toJson()));
  }
}
