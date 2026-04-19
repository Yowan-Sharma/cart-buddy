import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

class GoogleOAuthService {
  static const _clientId =
      '999311585680-congvfmh19825i3dh0ah9ro8qrrb4sai.apps.googleusercontent.com';
  static const _redirectScheme =
      'com.googleusercontent.apps.999311585680-congvfmh19825i3dh0ah9ro8qrrb4sai';
  static const _redirectUri = '$_redirectScheme:/oauth2redirect';

  /// Launches Google Sign-In in an in-app browser and returns a Google ID token.
  /// Works on both the iOS Simulator and physical devices.
  Future<String> getIdToken() async {
    final verifier = _generateVerifier();
    final challenge = _generateChallenge(verifier);

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    // Opens SFSafariViewController on iOS (works on simulator + device)
    final resultUrl = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _redirectScheme,
    );

    final code = Uri.parse(resultUrl).queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('Google Sign-In failed: no authorization code received.');
    }

    return _exchangeCodeForIdToken(code, verifier);
  }

  Future<String> _exchangeCodeForIdToken(
      String code, String verifier) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'code': code,
        'redirect_uri': _redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Google token exchange failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = data['id_token'] as String?;
    if (idToken == null) {
      throw Exception('Google token exchange returned no id_token.');
    }
    return idToken;
  }

  // ---- PKCE helpers ----

  String _generateVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _generateChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
