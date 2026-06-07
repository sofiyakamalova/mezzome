/// Runtime configuration. Override via `--dart-define` in CI / flavors later.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-dev.mezzome.com/api/v2',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Dev: restaurant for auto client registration when staff user is missing.
  static const int devRegistrationRestaurantId = int.fromEnvironment(
    'DEV_RESTAURANT_ID',
    defaultValue: 1,
  );
}
