class ApiEndpoints {
  static const String baseUrl = 'https://interlinkpos.com/sk_bags/api/v1';
  static const String server1ItemsBaseUrl = 'http://192.168.1.59:8000';
  static const String server2ItemsBaseUrl = 'http://192.168.1.52:8000';

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
  static const String orderDetail = '/staff/order/get_detail';
}
