// lib/core/error_handler.dart

class AppError {
  static String getMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred.';

    final msg = error.toString().toLowerCase();

    // Auth errors
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('invalid email or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user already registered')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email address before logging in.';
    }
    if (msg.contains('signup disabled') || msg.contains('sign up disabled')) {
      return 'New registrations are currently disabled. Contact your administrator.';
    }
    if (msg.contains('password') && msg.contains('short')) {
      return 'Password is too short. Please use at least 8 characters.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // Network errors
    if (msg.contains('network') ||
        msg.contains('socketexception') ||
        msg.contains('connection') ||
        msg.contains('unreachable') ||
        msg.contains('no route to host')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    // Database / RLS errors
    if (msg.contains('permission') ||
        msg.contains('rls') ||
        msg.contains('policy') ||
        msg.contains('row-level security') ||
        msg.contains('new row violates')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('duplicate') || msg.contains('unique')) {
      return 'This record already exists in the system.';
    }
    if (msg.contains('foreign key') || msg.contains('fk_')) {
      return 'Cannot complete action: related data is missing or invalid.';
    }
    if (msg.contains('not null') || msg.contains('null value in column')) {
      return 'Required information is missing. Please fill in all fields.';
    }
    if (msg.contains('null') && msg.contains('not found')) {
      return 'The requested data could not be found.';
    }

    // Auth session errors
    if (msg.contains('jwt') ||
        msg.contains('token') && msg.contains('invalid') ||
        msg.contains('session') && msg.contains('expired')) {
      return 'Your session has expired. Please log in again.';
    }

    // Storage errors
    if (msg.contains('storage') || msg.contains('bucket')) {
      return 'File upload failed. Please check the file and try again.';
    }
    if (msg.contains('too large') || msg.contains('size limit')) {
      return 'File is too large. Maximum size is 5MB.';
    }

    // Generic
    return 'Something went wrong. Please try again or contact support.';
  }

  /// Returns true if the error is an auth/session error requiring re-login
  static bool requiresReLogin(dynamic error) {
    if (error == null) return false;
    final msg = error.toString().toLowerCase();
    return msg.contains('jwt') ||
        (msg.contains('token') && msg.contains('invalid')) ||
        (msg.contains('session') && msg.contains('expired')) ||
        msg.contains('refresh_token_not_found');
  }
}