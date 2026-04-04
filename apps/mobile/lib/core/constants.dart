class AppConstants {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://balanceflow-api-65pq.onrender.com',
  );
  static const tokenKey = 'bf_token';
}
