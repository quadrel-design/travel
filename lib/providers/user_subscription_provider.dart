import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_subscription_service.dart';
import 'package:logger/logger.dart';

/// Provider that exposes the current user subscription status.
///
/// This provider maintains the state of whether the user has a 'pro' or 'free'
/// subscription, fetched from Firebase Auth custom claims, and allows toggling
/// between these states.
///
/// Usage:
/// ```dart
/// final subscription = ref.watch(userSubscriptionProvider);
/// if (subscription == 'pro') {
///   // Show pro features
/// }
/// ```
final userSubscriptionProvider =
    StateNotifierProvider<UserSubscriptionNotifier, String>((ref) {
  return UserSubscriptionNotifier();
});

/// Notifier class that manages the subscription state.
///
/// This class handles initializing the subscription status from Firebase Auth
/// and provides a method to toggle between 'pro' and 'free' subscription tiers.
class UserSubscriptionNotifier extends StateNotifier<String> {
  /// Service used to interact with the subscription APIs.
  final _service = UserSubscriptionService();
  final _logger = Logger();

  /// Creates a UserSubscriptionNotifier with initial state of 'free'.
  ///
  /// Immediately starts loading the actual subscription status from Firebase.
  UserSubscriptionNotifier() : super('free') {
    _logger.d('[UserSubNotifier] Initializing with state: $state');
    _init();
  }

  /// Initializes the subscription state by fetching from Firebase Auth.
  ///
  /// Called automatically when the notifier is created.
  Future<void> _init() async {
    _logger.d('[UserSubNotifier] _init: Fetching current subscription...');
    try {
      final currentSub = await _service.getCurrentSubscription();
      _logger.d(
          '[UserSubNotifier] _init: Fetched subscription: $currentSub. Updating state.');
      state = currentSub;
    } catch (e, s) {
      _logger.e(
          '[UserSubNotifier] _init: Error fetching subscription. State remains $state.',
          error: e,
          stackTrace: s);
    }
  }

  /// Toggles the subscription status between 'pro' and 'free'.
  ///
  /// Makes an API call to update the subscription status in Firebase Auth
  /// and updates the local state with the new value.
  Future<void> toggle() async {
    _logger.d('[UserSubNotifier] toggle: Current state before toggle: $state');
    try {
      final newSubscriptionStatus = await _service.toggleSubscription();
      _logger.d(
          '[UserSubNotifier] toggle: Service returned new status: $newSubscriptionStatus. Updating state.');
      state = newSubscriptionStatus;
      _logger.d('[UserSubNotifier] toggle: State after update: $state');
    } catch (e, s) {
      _logger.e(
          '[UserSubNotifier] toggle: Error during toggle. State remains $state.',
          error: e,
          stackTrace: s);
      // Optionally rethrow if the UI needs to know about the error directly from the notifier's method call
      // For now, the UI catches it from ref.read().toggle()
    }
  }
}
