class ApiEndpoints {
  static const String interlinkServerUrl = 'https://interlinkpos.com';
  static const String baseUrl = '$interlinkServerUrl/sk_bags/api/v1';
  static const String ahmLabel = 'SK ENTERPRISE';
  static const String bhuLabel = 'SS MOVE ON THRILL BAGS LLP';
  static const String ahmItemsBaseUrl = 'http://182.70.120.80:8008';
  static const String bhuItemsBaseUrl = 'http://150.107.237.206:8009';

  static const String login = '/staff/auth/login';
  static const String refreshToken = '/staff/auth/refresh_token';
  static const String apiAccessKey = 'ZkC6BDUzxz';
  static const String managerBranchRead = '/manager/master/branch/read';

  static const String getProfile = '/staff/auth/get_profile';
  static const String scanQrcode = '/staff/stock/scan_qrcode';
  static const String stockStoreCreate = '/staff/stock/store/0';
  static const String stockRead = '/staff/stock/read';
  static const String stockRemove = '/staff/stock/remove';
  static const String orderRead = '/staff/order/read';
  static const String orderStore = '/staff/order/store/0';
  static String orderStoreById(String orderId) => '/staff/order/store/$orderId';
  static const String orderDetail = '/staff/order/get_detail';
  static const String repairRead = '/staff/repairing/read';
  static const String repairStore = '/staff/repairing/store/0';
  static String repairStoreById(String repairId) =>
      '/staff/repairing/store/$repairId';
  static const String repairDetail = '/staff/repairing/get_detail';
}
