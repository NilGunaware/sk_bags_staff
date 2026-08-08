class ApiEndpoints {
  static const String interlinkServerUrl = 'https://interlinkpos.com';
  static const String baseUrl = '$interlinkServerUrl/sk_bags/api/v1';
  static const String apiAccessKey = 'ZkC6BDUzxz';

  static String get login => 'workshop/auth/login';
  static String get refreshToken => 'workshop/auth/refresh_token';
  static String get logout => 'workshop/auth/logout';
  static String get getProfile => 'workshop/auth/get_profile';

  static String get repairRead => 'workshop/repairing/read';
  static String get repairStore => 'workshop/repairing/store/0';
  static String repairStoreById(String repairId) => 'workshop/repairing/store/$repairId';
  static String get repairDetail => 'workshop/repairing/get_detail';
}
