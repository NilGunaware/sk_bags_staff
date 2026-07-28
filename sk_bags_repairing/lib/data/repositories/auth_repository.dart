import '../../core/constants/api_endpoints.dart';
import '../models/login_response.dart';
import '../providers/api_provider.dart';

class AuthRepository {
  AuthRepository(this._apiProvider);

  final ApiProvider _apiProvider;

  Future<LoginResponse> login({required String mobileNumber, required String password, String expiryIn = '84600', String? branchId, required String role}) async {
    ApiEndpoints.activeRole = role;
    final payload = {'mobile_no': mobileNumber, 'password': password, 'branch_id': branchId, 'expiry_time': expiryIn};
    if (role == 'staff' && branchId != null && branchId.isNotEmpty) {
      payload['branch_id'] = branchId;
    }

    final response = await _apiProvider.post(ApiEndpoints.login, data: payload);
    return LoginResponse.fromJson(response);
  }
}
