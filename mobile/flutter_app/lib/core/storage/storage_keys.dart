abstract final class StorageKeys {
  // Entries stored under the pre-rename keys are copied to these names by
  // storage_migration.dart before any repository reads them.
  static const authSession = 'questrace:auth-session';
  static const questionDraft = 'questrace:question-draft';
  static const apiBaseUrl = 'questrace:api-base-url';
  static const themeColorSeed = 'questrace:theme-color-seed';
}
