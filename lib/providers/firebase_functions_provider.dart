import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_functions_service.dart';
import 'logging_provider.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctionsService>((ref) {
  return FirebaseFunctionsService(
    logger: ref.watch(loggerProvider),
  );
});
