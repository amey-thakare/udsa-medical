import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiErrorHandler {
  static String extract(dynamic error, {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is DioException) {
      // 1. Network / Timeout errors
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'The request timed out. Please try again.';
      }

      if (error.type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return 'Unable to connect. Please check your internet connection.';
      }

      // 2. Server Response errors
      final response = error.response;
      if (response != null) {
        final statusCode = response.statusCode;
        final data = response.data;

        String? serverError;
        String? serverCode;

        if (data is Map<String, dynamic>) {
          serverError = data['message'] as String? ?? data['error'] as String?;
          serverCode = data['code'] as String?;
        } else if (data is String && data.isNotEmpty) {
          serverError = data;
        }

        // 401 Unauthorized
        if (statusCode == 401) {
          return 'Your session has expired. Please sign in again.';
        }

        // 403 Forbidden
        if (statusCode == 403) {
          return 'Access denied. You do not have permission to view this document.';
        }

        // 404 Not Found
        if (statusCode == 404) {
          return 'The requested document or resource was not found.';
        }

        // 409 Conflict - Email already exists
        if (statusCode == 409 ||
            serverCode == 'EMAIL_ALREADY_EXISTS' ||
            (serverError != null &&
                (serverError.toLowerCase().contains('already exists') ||
                 serverError.toLowerCase().contains('already registered')))) {
          return 'An account with this email already exists. Please sign in.';
        }

        // 400 / 422 Validation errors
        if (statusCode == 400 || statusCode == 422 || serverCode == 'VALIDATION_ERROR') {
          if (serverError != null) {
            final lower = serverError.toLowerCase();
            if (lower.contains('invalid email') || lower.contains('valid email')) {
              return 'Please enter a valid email address.';
            }
            if (lower.contains('password') &&
                (lower.contains('6') || lower.contains('short') || lower.contains('least') || lower.contains('length'))) {
              return 'Your password does not meet the minimum length requirement.';
            }
            return serverError;
          }
          return 'Invalid request details. Please check your inputs.';
        }

        // 503 Service Unavailable / Database Down
        if (statusCode == 503 ||
            serverCode == 'DATABASE_UNAVAILABLE' ||
            serverCode == 'SERVICE_UNAVAILABLE') {
          return 'The service is temporarily unavailable. Please try again later.';
        }

        // 500 Internal Server Error
        if (statusCode == 500) {
          return 'The service is temporarily unavailable. Please try again later.';
        }

        // Return any safe message provided by server
        if (serverError != null &&
            serverError.isNotEmpty &&
            !serverError.contains('stack') &&
            !serverError.contains('prisma') &&
            !serverError.contains('Error querying the database')) {
          return serverError;
        }
      }

      if (kDebugMode) {
        debugPrint('DioException details: ${error.message}, status: ${error.response?.statusCode}');
      }
      return fallback;
    }

    if (error is String) {
      return error;
    }

    if (kDebugMode) {
      debugPrint('Unhandled error: $error');
    }
    return fallback;
  }
}
