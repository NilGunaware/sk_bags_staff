import '../../core/constants/api_endpoints.dart';
import '../models/login_response.dart';
import '../providers/api_provider.dart';

class AuthRepository {
  AuthRepository(this._apiProvider);

  final ApiProvider _apiProvider;

  Future<LoginResponse> login({
    required String mobileNumber,
    required String password,
    String expiryIn = '86400',
    String? branchId,
    required String role,
  }) async {
    final payload = <String, dynamic>{
      'mobile_no': mobileNumber,
      'password': password,
      'expiry_time': expiryIn,
    };
    if (branchId != null && branchId.isNotEmpty) {
      payload['branch_id'] = branchId;
    }

    final response = await _apiProvider.post(ApiEndpoints.login, data: payload);
    return LoginResponse.fromJson(response);
  }
}
