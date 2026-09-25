import '../../../core/network/api_client.dart';

/// Thrown by a login call when the password was right but the account has
/// two-factor authentication on — the login isn't finished yet. The caller
/// shows TwoFactorCodeScreen with this challenge, which exchanges it plus
/// the code for the session token.
class TwoFactorRequired implements Exception {
  const TwoFactorRequired({
    required this.challengeToken,
    required this.channel,
    required this.destination,
  });

  factory TwoFactorRequired.fromJson(Map<String, dynamic> json) {
    return TwoFactorRequired(
      challengeToken: json['challenge_token'] as String,
      channel: json['channel'] as String? ?? 'sms',
      destination: json['destination'] as String? ?? '',
    );
  }

  final String challengeToken;

  /// 'sms' (Transporter Company) or 'email' (Customer).
  final String channel;

  /// Masked, e.g. "**********678" or "a****@example.com".
  final String destination;

  /// Throws if a login response is a two-factor challenge rather than a
  /// finished login; otherwise returns the session token.
  static String tokenOrThrow(Map<String, dynamic> body) {
    if (body['two_factor_required'] == true) {
      throw TwoFactorRequired.fromJson(body);
    }
    return body['token'] as String;
  }
}

/// The second login step, shared by both roles (the backend picks SMS or
/// email per account).
class TwoFactorRepository {
  TwoFactorRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Returns the session's bearer token.
  Future<String> verify({required String challengeToken, required String code}) async {
    final body = await _client.post(
      '/auth/login/two-factor',
      data: {'challenge_token': challengeToken, 'code': code},
    );
    return body['token'] as String;
  }

  Future<void> resend({required String challengeToken}) {
    return _client.post('/auth/login/two-factor/resend', data: {'challenge_token': challengeToken});
  }
}
