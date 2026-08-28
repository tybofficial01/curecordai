import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around [GoogleSignIn] shared by the login and sign-up
/// screens so both reuse the same client configuration and instance.
class GoogleSignInService {
  GoogleSignInService._();

  static final GoogleSignIn _instance = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        '163511439914-1avrk8ab66oui774dkoqaqe38sl3uidu.apps.googleusercontent.com',
  );

  /// Returns the Google ID token for the signed-in account, or `null` if
  /// the user cancelled the sign-in flow.
  static Future<String?> signInAndGetIdToken() async {
    final account = await _instance.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }
}
