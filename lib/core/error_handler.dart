// lib/core/error_handler.dart

class AppError {
  static String getMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred.';
    
    final msg = error.toString().toLowerCase();
    
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email already registered') || msg.contains('already been registered')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (msg.contains('network') || msg.contains('socketexception') || msg.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('permission') || msg.contains('rls') || msg.contains('policy')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('duplicate') || msg.contains('unique')) {
      return 'This record already exists in the system.';
    }
    if (msg.contains('null') || msg.contains('not found')) {
      return 'The requested data could not be found.';
    }
    if (msg.contains('jwt') || msg.contains('token') || msg.contains('session')) {
      return 'Your session has expired. Please log in again.';
    }
    
    return 'Something went wrong. Please try again or contact support.';
  }
}
