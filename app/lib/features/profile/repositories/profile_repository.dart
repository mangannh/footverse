import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/models/api_response.dart';
import '../../auth/models/user_response.dart';
import '../models/change_email_request.dart';
import '../models/change_password_request.dart';
import '../models/update_profile_request.dart';

/// The typed client of the four frozen `/users/me` endpoints (dto-spec §20):
/// read the caller's profile, update its editable fields, and the two
/// re-authenticated credential changes (password, email).
///
/// It only calls the API, unwraps the [ApiResponse] envelope, and returns the
/// typed payload — throwing [AppException] on failure (the injected [Dio]'s
/// `ErrorInterceptor` has already mapped the transport error, and its
/// `AuthInterceptor` has attached the bearer). It holds no business logic and
/// touches no storage, token, or navigation, so every enveloped business error
/// (`USER_CURRENT_PASSWORD_INVALID` — error-spec §8.13, `USER_EMAIL_DUPLICATED`
/// and `USER_PHONE_DUPLICATED` — error-spec §8.2) propagates unchanged as an
/// [AppException] carrying the registry code. The reused [UserResponse] is the
/// shared model owned by the auth feature (Sprint 9 Design Decision 1); the
/// email-change token consequence is handled transparently by the existing
/// `AuthInterceptor`, so this repository adds no token logic.
class ProfileRepository {
  const ProfileRepository(this._dio);

  static const String _mePath = '/api/v1/users/me';
  static const String _passwordPath = '/api/v1/users/me/password';
  static const String _emailPath = '/api/v1/users/me/email';

  final Dio _dio;

  /// `GET /users/me` — the signed-in caller's own profile.
  Future<UserResponse> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_mePath);
      return _unwrapUser(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `PUT /users/me` — update the caller's editable profile fields.
  Future<UserResponse> updateProfile(UpdateProfileRequest request) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        _mePath,
        data: request.toJson(),
      );
      return _unwrapUser(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `PATCH /users/me/password` — change the caller's password (re-authenticated).
  Future<void> changePassword(ChangePasswordRequest request) async {
    try {
      await _dio.patch<void>(_passwordPath, data: request.toJson());
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `PATCH /users/me/email` — change the caller's email (re-authenticated),
  /// returning the updated profile.
  Future<UserResponse> changeEmail(ChangeEmailRequest request) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        _emailPath,
        data: request.toJson(),
      );
      return _unwrapUser(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  UserResponse _unwrapUser(Response<Map<String, dynamic>> response) {
    final envelope = ApiResponse<UserResponse>.fromJson(
      response.data!,
      (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  AppException _asAppException(DioException exception) {
    final error = exception.error;
    if (error is AppException) {
      return error;
    }
    return const AppException(message: 'An unexpected error occurred');
  }
}
