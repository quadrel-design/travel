# Firestore to PostgreSQL Migration Plan

## Key Components to Remove or Replace

### 1. Firestore Providers and Stream Providers

- **Remove/Replace in `lib/providers/repository_providers.dart`**:
  - `firestoreProvider` - Replace with PostgreSQL provider
  - `userInvoicesStreamProvider` - Replace with REST/PostgreSQL-based data fetching 
  - `invoiceImagesStreamProvider` - Replace with REST/PostgreSQL-based data fetching
  - `invoiceStreamProvider` - Replace with REST/PostgreSQL-based data fetching
  - `projectImagesStreamProvider` - Replace with REST/PostgreSQL-based data fetching
  - `expensesStreamProvider` - Replace with REST/PostgreSQL-based data fetching

### 2. Firestore Repositories

- **Replace `lib/repositories/firestore_invoice_repository.dart`** with PostgreSQL-based repository
- **Replace `lib/repositories/expense_repository.dart`** with PostgreSQL-based repository

### 3. Firestore Stream Implementations in Flutter App

- **Update UI components to use polling or REST-based data fetching instead of streams:**
  - `lib/screens/invoices/invoice_capture_overview_screen.dart`
  - `lib/screens/project/project_detail_screen.dart`
  - `lib/screens/home_screen.dart`

### 4. Firestore-Specific Model Adaptations 

- **Update model classes to remove Firestore-specific conversions:**
  - `lib/models/invoice_image_process.dart`
  - `lib/models/project.dart`
  - `lib/models/user.dart`

### 5. Remove Firestore Imports

Search for and remove imports across the codebase:
- `import 'package:cloud_firestore/cloud_firestore.dart'`
- References to `FirebaseFirestore.instance`
- References to `DocumentReference`, `CollectionReference`
- References to `Timestamp` conversions

### 6. Firebase-only Components to Keep

- **Keep Firebase Auth**:
  - `lib/repositories/firebase_auth_repository.dart` (authentication still uses Firebase)
  - `lib/services/user_subscription_service.dart` (uses Firebase Auth for custom claims)

## Implementation Strategy

1. **Create PostgreSQL Repository Implementations**:
   - Create `postgres_invoice_repository.dart` implementing the `InvoiceRepository` interface
   - Create `postgres_expense_repository.dart` implementing the `ExpenseRepository` interface

2. **Replace Stream Providers with REST/HTTP Providers**:
   - Create new providers that use HTTP requests to fetch data from PostgreSQL backend
   - Implement polling or manual refresh mechanisms where real-time updates are needed

3. **Update UI Components**:
   - Replace stream-based UI with traditional data fetching patterns
   - Add loading states and manual refresh buttons where needed

4. **Test Data Migration**:
   - Verify all data is correctly migrated from Firestore to PostgreSQL
   - Ensure referential integrity

5. **Clean Up**:
   - Remove all unused Firestore code
   - Remove Firestore SDK dependencies if no longer needed

## Backend Changes

1. **Complete Migration of Backend Services**:
   - Ensure all cloud functions now use PostgreSQL instead of Firestore
   - Update error handling in backend services to handle PostgreSQL errors

2. **Update API Endpoints**:
   - Update all API endpoints to use PostgreSQL queries
   - Add any additional endpoints needed for complex queries

## Testing Strategy

1. Test each migrated component in isolation
2. Perform integration testing of complete flows
3. Test error scenarios and edge cases
4. Verify performance under load 