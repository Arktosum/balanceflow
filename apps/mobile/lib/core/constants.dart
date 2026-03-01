class AppConstants {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://balanceflow-api-65pq.onrender.com',
  );
  static const tokenKey = 'app_token';
  static const maxSyncRetries = 3;
}