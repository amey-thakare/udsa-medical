import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medrecord/utils/error_handler.dart';

void main() {
  group('ApiErrorHandler', () {
    test('maps connection timeout', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(ApiErrorHandler.extract(error), 'The request timed out. Please try again.');
    });

    test('maps connection error / no internet', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );
      expect(ApiErrorHandler.extract(error), 'Unable to connect. Please check your internet connection.');
    });

    test('maps 409 conflict email already registered', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 409,
          data: {
            'success': false,
            'code': 'EMAIL_ALREADY_EXISTS',
            'message': 'An account with this email already exists.',
          },
        ),
      );
      expect(ApiErrorHandler.extract(error), 'An account with this email already exists. Please sign in.');
    });

    test('maps 400 invalid email', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 400,
          data: {
            'success': false,
            'code': 'VALIDATION_ERROR',
            'error': 'Invalid email address',
          },
        ),
      );
      expect(ApiErrorHandler.extract(error), 'Please enter a valid email address.');
    });

    test('maps 400 password too short', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 400,
          data: {
            'success': false,
            'code': 'VALIDATION_ERROR',
            'error': 'Password must be at least 6 characters',
          },
        ),
      );
      expect(ApiErrorHandler.extract(error), 'Your password does not meet the minimum length requirement.');
    });

    test('maps 503 service unavailable / database error', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 503,
          data: {
            'success': false,
            'code': 'DATABASE_UNAVAILABLE',
            'error': 'The database service is temporarily unavailable. Please try again later.',
          },
        ),
      );
      expect(ApiErrorHandler.extract(error), 'The service is temporarily unavailable. Please try again later.');
    });

    test('maps 500 internal server error', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 500,
          data: {'error': 'Internal server error'},
        ),
      );
      expect(ApiErrorHandler.extract(error), 'The service is temporarily unavailable. Please try again later.');
    });
  });
}
