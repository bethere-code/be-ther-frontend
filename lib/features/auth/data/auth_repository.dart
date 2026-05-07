import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_exception.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<LoginOtpRequestResult> requestLoginOtp(String identifier) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login/otp/request',
        data: {'identifier': identifier},
      );
      final data = _unwrap(res) as Map<String, dynamic>;
      return LoginOtpRequestResult(
        destinationLabel: data['destinationLabel'] as String? ?? identifier,
      );
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Failed to request OTP');
    }
  }

  Future<void> requestSignupOtp({
    required String displayName,
    required String username,
    required String email,
    required String password,
    int? age,
  }) async {
    try {
      final body = <String, dynamic>{
        'displayName': displayName,
        'username': username,
        'email': email,
        'password': password,
      };
      if (age != null) body['age'] = age;
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup/request-otp',
        data: body,
      );
      _unwrap(res);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Failed to send verification code');
    }
  }

  Future<SignupAvailability> checkSignupAvailability({
    String? username,
    String? email,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username;
      if (email != null) payload['email'] = email;
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup/availability',
        data: payload,
        // Live validation should fail fast and not block typing UX.
        options: Options(
          connectTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final data = _unwrap(res) as Map<String, dynamic>;
      return SignupAvailability.fromJson(data);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Could not validate sign-up fields');
    }
  }

  Future<AuthTokens> verifyLoginOtp({
    required String identifier,
    required String code,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login/otp/verify',
        data: {'identifier': identifier, 'code': code},
      );
      final data = _unwrap(res);
      return AuthTokens.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Failed to verify OTP');
    }
  }

  Future<AuthTokens> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login/password',
        data: {'identifier': identifier, 'password': password},
      );
      final data = _unwrap(res);
      return AuthTokens.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Failed to log in');
    }
  }

  Future<AuthTokens> verifySignupOtp({
    required String email,
    required String code,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/signup/verify',
        data: {'email': email, 'code': code},
      );
      final data = _unwrap(res);
      return AuthTokens.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Failed to verify OTP');
    }
  }

  Future<AuthTokens> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'openid', 'profile'],
    );
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException(
        'Missing Google idToken (check GOOGLE_WEB_CLIENT_ID / SHA config)',
      );
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/google',
        data: {'idToken': idToken},
      );
      final data = _unwrap(res);
      return AuthTokens.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Google sign-in failed');
    }
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = _unwrap(res);
      return AuthTokens.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Session refresh failed');
    }
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return _unwrap(res) as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toApiException(e, fallback: 'Failed to load account');
    }
  }

  dynamic _unwrap(Response<Map<String, dynamic>> res) {
    final body = res.data;
    if (body == null) throw ApiException('Empty response');
    if (body['ok'] != true) {
      final err = body['error'];
      final msg = err is Map && err['message'] != null
          ? err['message'].toString()
          : 'Request failed';
      throw ApiException(msg);
    }
    return body['data'];
  }

  ApiException _toApiException(DioException e, {required String fallback}) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map && error['message'] != null) {
        return ApiException(error['message'].toString());
      }
      if (error is String && error.isNotEmpty) {
        return ApiException(error);
      }
    }
    if (status == 404) {
      return ApiException(
        'Auth API route not found. Ensure backend is running latest code (`npm run dev`) on port 3000.',
      );
    }
    if (status == 500) {
      return ApiException(
        'Server error while processing auth. Check backend logs.',
      );
    }
    return ApiException(e.message ?? fallback);
  }
}

class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic>? user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: json['user'] is Map<String, dynamic>
          ? json['user'] as Map<String, dynamic>
          : null,
    );
  }
}

class SignupAvailability {
  SignupAvailability({this.username, this.email});

  final SignupAvailabilityField? username;
  final SignupAvailabilityField? email;

  factory SignupAvailability.fromJson(Map<String, dynamic> json) {
    SignupAvailabilityField? parseField(dynamic value) {
      if (value is! Map<String, dynamic>) return null;
      return SignupAvailabilityField(
        available: value['available'] as bool? ?? false,
        reason: value['reason'] as String?,
      );
    }

    return SignupAvailability(
      username: parseField(json['username']),
      email: parseField(json['email']),
    );
  }
}

class SignupAvailabilityField {
  SignupAvailabilityField({required this.available, this.reason});

  final bool available;
  final String? reason;
}

class LoginOtpRequestResult {
  LoginOtpRequestResult({required this.destinationLabel});

  final String destinationLabel;
}
