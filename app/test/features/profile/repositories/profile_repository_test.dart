import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/profile/models/change_email_request.dart';
import 'package:footverse/features/profile/models/change_password_request.dart';
import 'package:footverse/features/profile/models/update_profile_request.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'profile_repository_test.mocks.dart';

Map<String, dynamic> _userData() => <String, dynamic>{
  'id': 1,
  'email': 'user@example.com',
  'fullName': 'Nguyen Van A',
  'phone': '0901234567',
  'avatarUrl': 'https://cdn.example.com/a.jpg',
  'role': 'CUSTOMER',
  'enabled': true,
  'createdAt': '2025-01-15T10:30:00',
  'updatedAt': '2025-01-16T08:00:00',
};

Response<Map<String, dynamic>> _envelope(String path, Object data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{
        'success': true,
        'message': 'OK',
        'data': data,
        'timestamp': '2025-01-15T10:30:00',
      },
    );

Response<void> _voidResponse(String path) =>
    Response<void>(requestOptions: RequestOptions(path: path), statusCode: 200);

DioException _errorWith(String errorCode, int statusCode) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/users/me'),
  error: AppException(
    message: 'error',
    statusCode: statusCode,
    errorCode: errorCode,
  ),
);

const UpdateProfileRequest _updateRequest = UpdateProfileRequest(
  fullName: 'Nguyen Van A',
  phone: '0901234567',
  avatarUrl: 'https://cdn.example.com/a.jpg',
);

const ChangePasswordRequest _passwordRequest = ChangePasswordRequest(
  currentPassword: 'oldPass1',
  newPassword: 'newPass2',
);

const ChangeEmailRequest _emailRequest = ChangeEmailRequest(
  newEmail: 'new@example.com',
  currentPassword: 'oldPass1',
);

@GenerateNiceMocks([MockSpec<Dio>()])
void main() {
  late MockDio dio;
  late ProfileRepository repository;

  setUp(() {
    dio = MockDio();
    repository = ProfileRepository(dio);
  });

  group('getMe', () {
    test('GETs the users-me path and returns the typed user', () async {
      when(
        dio.get<Map<String, dynamic>>(any),
      ).thenAnswer((_) async => _envelope('/api/v1/users/me', _userData()));

      final user = await repository.getMe();

      final captured = verify(
        dio.get<Map<String, dynamic>>(captureAny),
      ).captured;
      expect(captured[0], '/api/v1/users/me');
      expect(user.id, 1);
      expect(user.email, 'user@example.com');
      expect(user.fullName, 'Nguyen Van A');
      expect(user.phone, '0901234567');
      expect(user.role, Role.customer);
      expect(user.enabled, isTrue);
    });
  });

  group('updateProfile', () {
    test('PUTs the users-me path with the body, returns the user', () async {
      when(
        dio.put<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenAnswer((_) async => _envelope('/api/v1/users/me', _userData()));

      final user = await repository.updateProfile(_updateRequest);

      final captured = verify(
        dio.put<Map<String, dynamic>>(
          captureAny,
          data: captureAnyNamed('data'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/users/me');
      expect(captured[1], _updateRequest.toJson());
      expect(user.id, 1);
      expect(user.fullName, 'Nguyen Van A');
    });

    test('surfaces USER_PHONE_DUPLICATED as a typed AppException', () async {
      when(
        dio.put<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('USER_PHONE_DUPLICATED', 409));

      await expectLater(
        repository.updateProfile(_updateRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'USER_PHONE_DUPLICATED',
          ),
        ),
      );
    });
  });

  group('changePassword', () {
    test('PATCHes the password path with the body, returns void', () async {
      when(
        dio.patch<void>(any, data: anyNamed('data')),
      ).thenAnswer((_) async => _voidResponse('/api/v1/users/me/password'));

      await repository.changePassword(_passwordRequest);

      final captured = verify(
        dio.patch<void>(captureAny, data: captureAnyNamed('data')),
      ).captured;
      expect(captured[0], '/api/v1/users/me/password');
      expect(captured[1], _passwordRequest.toJson());
    });

    test(
      'surfaces USER_CURRENT_PASSWORD_INVALID as a typed AppException',
      () async {
        when(
          dio.patch<void>(any, data: anyNamed('data')),
        ).thenThrow(_errorWith('USER_CURRENT_PASSWORD_INVALID', 400));

        await expectLater(
          repository.changePassword(_passwordRequest),
          throwsA(
            isA<AppException>().having(
              (e) => e.errorCode,
              'errorCode',
              'USER_CURRENT_PASSWORD_INVALID',
            ),
          ),
        );
      },
    );
  });

  group('changeEmail', () {
    test('PATCHes the email path with the body, returns the user', () async {
      when(
        dio.patch<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _envelope(
          '/api/v1/users/me/email',
          _userData()..['email'] = 'new@example.com',
        ),
      );

      final user = await repository.changeEmail(_emailRequest);

      final captured = verify(
        dio.patch<Map<String, dynamic>>(
          captureAny,
          data: captureAnyNamed('data'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/users/me/email');
      expect(captured[1], _emailRequest.toJson());
      expect(user.email, 'new@example.com');
    });

    test('surfaces USER_EMAIL_DUPLICATED as a typed AppException', () async {
      when(
        dio.patch<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('USER_EMAIL_DUPLICATED', 409));

      await expectLater(
        repository.changeEmail(_emailRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'USER_EMAIL_DUPLICATED',
          ),
        ),
      );
    });
  });
}
