/// Cutover switches. Database is Supabase-only; Firebase dual-write/fallback
/// remain off permanently unless explicitly re-enabled for emergency recovery.
class MigrationConfig {
  const MigrationConfig._();

  static const useFirestoreReadFallback = bool.fromEnvironment(
    'MIGRATION_FIRESTORE_READ_FALLBACK',
    defaultValue: false,
  );

  static const useFirestoreDualWrite = bool.fromEnvironment(
    'MIGRATION_FIRESTORE_DUAL_WRITE',
    defaultValue: false,
  );

  static bool get supabaseReadPrimary => true;
}
