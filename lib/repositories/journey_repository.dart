// This file exists for backward compatibility with old code that references JourneyRepository
// It simply re-exports the InvoiceRepository interface

export 'invoice_repository.dart';

// Create an alias for the type
import 'invoice_repository.dart';

typedef JourneyRepository = InvoiceRepository;
