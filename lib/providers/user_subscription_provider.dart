import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_subscription_service.dart';

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

  /// Creates a UserSubscriptionNotifier with initial state of 'free'.
  ///
  /// Immediately starts loading the actual subscription status from Firebase.
  UserSubscriptionNotifier() : super('free') {
    _init();
  }

  /// Initializes the subscription state by fetching from Firebase Auth.
  ///
  /// Called automatically when the notifier is created.
  Future<void> _init() async {
    state = await _service.getCurrentSubscription();
  }

  /// Toggles the subscription status between 'pro' and 'free'.
  ///
  /// Makes an API call to update the subscription status in Firebase Auth
  /// and updates the local state with the new value.
  Future<void> toggle() async {
    state = await _service.toggleSubscription();
  }
}
