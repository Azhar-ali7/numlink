import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_mode.dart';
import '../models/chain_node.dart';
import '../models/puzzle.dart';

/// A snapshot of an in-progress game, enough to resume after the app is killed.
class GameSession {
  const GameSession({
    required this.mode,
    required this.difficulty,
    required this.puzzle,
    required this.chain,
    required this.used,
    required this.hintsUsed,
    required this.resets,
  });

  final GameMode mode;
  final Difficulty difficulty;
  final Puzzle puzzle;
  final List<ChainNode> chain;
  final Map<String, int> used;
  final int hintsUsed;
  final int resets;

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'difficulty': difficulty.name,
        'puzzle': puzzle.toJson(),
        'chain': chain.map((c) => c.toJson()).toList(),
        'used': used,
        'hintsUsed': hintsUsed,
        'resets': resets,
      };

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        mode: GameMode.values.byName(j['mode'] as String),
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        puzzle: Puzzle.fromJson(j['puzzle'] as Map<String, dynamic>),
        chain: (j['chain'] as List)
            .map((e) => ChainNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        used: (j['used'] as Map).map((k, v) => MapEntry(k as String, v as int)),
        hintsUsed: j['hintsUsed'] as int? ?? 0,
        resets: j['resets'] as int? ?? 0,
      );
}

/// Persistence seam for the in-progress game (resume across restarts). Mirrors
/// [StatsRepository]; a remote impl could sync it per-account with no caller
/// changes.
abstract class SessionRepository {
  Future<GameSession?> load();
  Future<void> save(GameSession session);
  Future<void> clear();
}

class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'numlink_session';

  @override
  Future<GameSession?> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return GameSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt/old snapshot — start fresh
    }
  }

  @override
  Future<void> save(GameSession session) async {
    await _prefs.setString(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
