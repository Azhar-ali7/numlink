import '../models/game_stats.dart';

// ponytail: intentional YAGNI — kept as the seam for the long-term
// account/progress-sync plan. Delete if that plan is dropped.
/// Long-term account seam (interface only — no implementation yet).
///
/// The roadmap: let players sign in so progress (streak, stats, per-day
/// results) is logged server-side and synced across devices. When that lands,
/// a concrete `AccountService` plus a `RemoteStatsRepository` implement these
/// contracts and `main.dart` swaps the local bindings — the game controller,
/// screens, and widgets stay unchanged.
abstract class AccountService {
  /// Current signed-in user id, or null when playing locally/anonymously.
  String? get userId;

  Future<void> signInWithEmail(String email);
  Future<void> signOut();

  /// Push local progress up after sign-in.
  Future<void> syncUp(GameStats local);

  /// Pull the authoritative server-side stats.
  Future<GameStats?> syncDown();
}

/// The default no-op implementation used while the app is local-first.
class LocalOnlyAccountService implements AccountService {
  const LocalOnlyAccountService();

  @override
  String? get userId => null;

  @override
  Future<void> signInWithEmail(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> syncUp(GameStats local) async {}

  @override
  Future<GameStats?> syncDown() async => null;
}
