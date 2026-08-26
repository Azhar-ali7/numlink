/// Social/account features (leaderboard, Weekend Co-op, friend avatar stacks,
/// "a friend passed you" nudges). Off until accounts exist — `AccountService`
/// is a local-only no-op today and `userId` always returns null
/// (lib/account/account_service.dart:27). The gated widgets stay in the tree
/// so flipping this back to true restores them with no rework; release builds
/// tree-shake the unreachable branches out.
const bool kSocialEnabled = false;
