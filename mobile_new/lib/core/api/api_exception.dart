/// Base API exception class
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// 401 Unauthorized - invalid or expired token
class UnauthorizedException extends ApiException {
  const UnauthorizedException({String message = 'Unauthorized'})
      : super(message: message, statusCode: 401);
}

/// No internet connection
class NetworkException extends ApiException {
  const NetworkException({String message = 'No internet connection'})
      : super(message: message);
}

/// 5xx Server errors
class ServerException extends ApiException {
  const ServerException({String message = 'Server error', int? statusCode})
      : super(message: message, statusCode: statusCode);
}

/// 422 Validation errors with field-specific messages
class ValidationException extends ApiException {
  final Map<String, List<String>> errors;

  const ValidationException({
    required this.errors,
    String message = 'Validation failed',
  }) : super(message: message, statusCode: 422);

  /// Get first error message from any field
  String? get firstError {
    for (final messages in errors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return null;
  }

  /// Get error message for a specific field
  String? getFieldError(String field) {
    final messages = errors[field];
    return messages?.isNotEmpty == true ? messages!.first : null;
  }
}
