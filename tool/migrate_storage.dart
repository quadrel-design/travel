import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:travel/firebase_options.dart';
import 'package:travel/utils/storage_migration.dart';
import 'package:travel/services/storage/google_cloud_storage_client.dart';
import 'package:travel/services/storage/storage_service.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart tool/migrate_storage.dart <userId>');
    return;
  }
  final userId = args[0];

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final logger = Logger();
  final firebaseStorage = FirebaseStorage.instance;
  final storageService =
      GoogleCloudStorageClient(storage: firebaseStorage, logger: logger);

  final migration = StorageMigration(
    firebaseStorage: firebaseStorage,
    gcsStorage: storageService,
    logger: logger,
  );

  try {
    await migration.migrateUserFiles(userId);
    print('Migration complete for user: $userId');
  } catch (e, stackTrace) {
    print('Migration failed for user: $userId');
    print(e);
    print(stackTrace);
  }
}
