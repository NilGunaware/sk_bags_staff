import '../models/login_response.dart';
import '../providers/api_provider.dart';
import '../../core/constants/api_endpoints.dart';

class AuthRepository {
  AuthRepository(this._apiProvider);

  final ApiProvider _apiProvider;

  Future<LoginResponse> login({
    required String mobileNumber,
    required String password,
    //String expiryIn = '84600',
    String expiryIn = '60',
  }) async {
    final payload = {
      'mobile_no': mobileNumber,
      'password': password,
      'expiry_time': expiryIn,
    };

    final response =
        await _apiProvider.post(ApiEndpoints.login, data: payload);
    return LoginResponse.fromJson(response);
  }
}

