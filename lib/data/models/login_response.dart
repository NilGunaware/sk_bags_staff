class LoginResponse {
  LoginResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.raw,
  });

  final bool isSuccess;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? raw;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ??
        json['success'] ??
        json['error'] ??
        json['code'] ??
        json['response_code'];

    return LoginResponse(
      isSuccess: _parseStatus(status),
      message: (json['message'] ??
              json['msg'] ??
              json['error'] ??
              json['response_message'])
          ?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'])
          : (json['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(json['user'])
              : null),
      raw: json,
    );
  }

  static bool _parseStatus(dynamic status) {
    if (status is bool) return status;
    if (status is num) return status > 0;
    if (status is String) {
      final normalized = status.toLowerCase();
      return normalized == 'true' || normalized == 'success' || normalized == '200';
    }
    return false;
  }
}

