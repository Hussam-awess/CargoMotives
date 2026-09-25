import 'package:cargo_motives/features/auth/data/two_factor_repository.dart';

class FakeTwoFactorRepository extends TwoFactorRepository {
  FakeTwoFactorRepository({this.onVerify, this.onResend});

  final Future<String> Function(String challengeToken, String code)? onVerify;
  final Future<void> Function(String challengeToken)? onResend;

  @override
  Future<String> verify({required String challengeToken, required String code}) =>
      onVerify?.call(challengeToken, code) ?? Future.value('token-after-2fa');

  @override
  Future<void> resend({required String challengeToken}) => onResend?.call(challengeToken) ?? Future.value();
}
