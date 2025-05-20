import 'package:travel/repositories/base_repository_contracts.dart';

abstract class RepositoryImplEssentials implements BaseRepositoryForImages {
  // This class will inherit all abstract members from BaseRepositoryForImages
  // and BaseRepository. Concrete classes extending this will need to
  // provide implementations for fields like _logger, _baseUrl, etc., which
  // are then returned by the getter implementations required by the interfaces.
}
