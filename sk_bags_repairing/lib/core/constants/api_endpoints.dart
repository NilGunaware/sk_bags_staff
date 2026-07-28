class ApiEndpoints {
  static const String interlinkServerUrl = 'https://interlinkpos.com';
  static const String baseUrl = '$interlinkServerUrl/sk_bags/api/v1';
  static const String apiAccessKey = 'ZkC6BDUzxz';

  static String activeRole = 'staff';

  static bool get isWorkshop => activeRole == 'workshop';
  static String get rolePrefix => isWorkshop ? '/workshop' : '/staff';

  static String get login => '$rolePrefix/auth/login';
  static String get refreshToken => '$rolePrefix/auth/refresh_token';
  static String get logout => '$rolePrefix/auth/logout';
  static String get getProfile => '$rolePrefix/auth/get_profile';

  static const String managerBranchRead = '/manager/master/branch/read';

  static String get shopRead => '/workshop/master/shop/read';
  static String get shopStore => '/workshop/master/shop/store/0';
  static String shopStoreById(String id) => '/workshop/master/shop/store/$id';
  static String get repairRead => '$rolePrefix/repairing/read';
  static String get repairStore => '$rolePrefix/repairing/store/0';
  static String repairStoreById(String repairId) =>
      '$rolePrefix/repairing/store/$repairId';
  static String get repairDetail => '$rolePrefix/repairing/get_detail';
}
