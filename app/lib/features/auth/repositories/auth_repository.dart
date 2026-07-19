import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/models/api_response.dart';
import '../models/auth_response.dart';
import '../models/forgot_password_request.dart';
import '../models/login_request.dart';
import '../models/password_reset_token_response.dart';
import '../models/refresh_token_request.dart';
import '../models/register_request.dart';
import '../models/reset_password_request.dart';
import '../models/verify_reset_otp_request.dart';

/// The typed client of the frozen auth endpoints (dto-spec §20), including the
/// three-step password-reset flow (Sprint 13 Task 06).
///
/// It only calls the API, unwraps the [ApiResponse] envelope, and returns the
/// typed payload — throwing [AppException] on failure (the injected [Dio]'s
/// `ErrorInterceptor` has already mapped the transport error). It never touches
/// token storage, navigation, or auth state; the provider composes those
/// (flutter-guidelines §Error Handling; sprint-6-plan item 05). The
/// password-reset methods hold the same guarantee: they never sign the caller
/// in and never touch stored tokens, mirroring the backend keeping the whole
/// flow on `AuthService` rather than a separate repository (Design Decision 3).
class AuthRepository {
  const AuthRepository(this._dio);

  static const String _registerPath = '/api/v1/auth/register';
  static const String _loginPath = '/api/v1/auth/login';
  static const String _refreshPath = '/api/v1/auth/refresh';
  static const String _logoutPath = '/api/v1/auth/logout';
  static const String _forgotPasswordPath = '/api/v1/auth/forgot-password';
  static const String _verifyResetOtpPath = '/api/v1/auth/verify-reset-otp';
  static const String _resetPasswordPath = '/api/v1/auth/reset-password';

  final Dio _dio;

  Future<AuthResponse> register(RegisterRequest request) =>
      _authenticate(_registerPath, request.toJson());

  Future<AuthResponse> login(LoginRequest request) =>
      _authenticate(_loginPath, request.toJson());

  Future<AuthResponse> refresh(RefreshTokenRequest request) =>
      _authenticate(_refreshPath, request.toJson());

  Future<void> logout(RefreshTokenRequest request) async {
    try {
      await _dio.post<void>(_logoutPath, data: request.toJson());
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `POST /auth/forgot-password` — requests a password-reset one-time code by
  /// email. Always resolves on `200`, whether or not the account exists
  /// (non-enumeration).
  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    try {
      await _dio.post<void>(_forgotPasswordPath, data: request.toJson());
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `POST /auth/verify-reset-otp` — verifies the emailed one-time code and
  /// returns the opaque reset token that [resetPassword] consumes.
  Future<PasswordResetTokenResponse> verifyResetOtp(
    VerifyResetOtpRequest request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _verifyResetOtpPath,
        data: request.toJson(),
      );
      final envelope = ApiResponse<PasswordResetTokenResponse>.fromJson(
        response.data!,
        (json) =>
            PasswordResetTokenResponse.fromJson(json! as Map<String, dynamic>),
      );
      return envelope.data!;
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `POST /auth/reset-password` — sets a new password using a verified reset
  /// token. Never signs the caller in; the account remains signed out.
  Future<void> resetPassword(ResetPasswordRequest request) async {
    try {
      await _dio.post<void>(_resetPasswordPath, data: request.toJson());
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  Future<AuthResponse> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      final envelope = ApiResponse<AuthResponse>.fromJson(
        response.data!,
        (json) => AuthResponse.fromJson(json! as Map<String, dynamic>),
      );
      return envelope.data!;
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  AppException _asAppException(DioException exception) {
    final error = exception.error;
    if (error is AppException) {
      return error;
    }
    return const AppException(message: 'An unexpected error occurred');
  }
}
