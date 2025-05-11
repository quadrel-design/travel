// Temporary compatibility provider for Firebase Functions/Cloud Run services
// New code should use service_providers.dart and repository_providers.dart directly

export 'service_providers.dart'
    show cloudRunOcrServiceProvider, gcsFileServiceProvider, loggerProvider;
