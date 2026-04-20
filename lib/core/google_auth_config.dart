class GoogleAuthConfig {
  const GoogleAuthConfig._();

  // Google OAuth Web client ID. This is the value that should also be entered
  // first in Supabase Auth > Google provider > Client IDs.
  static const String _defaultWebClientId =
      '381834929556-g033bbsle20b7tl6mf56upqgk1qvt7ob.apps.googleusercontent.com';
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  // Native iOS Google OAuth client ID. Optional on Android, required for iOS.
  static const String _defaultIosClientId =
      '381834929556-rt6qe9legfkmotu3iaa17nipcj8bs63b.apps.googleusercontent.com';
  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: _defaultIosClientId,
  );

  static bool get hasWebClientId => webClientId.trim().isNotEmpty;
  static bool get hasIosClientId => iosClientId.trim().isNotEmpty;
}
