import 'package:flutter/services.dart';

/// Every phone number field in the app (login, sign-up, forgot password,
/// profile edits, driver entry, mobile-money) collects the same shape: a
/// local Tanzanian mobile number typed as 10 digits starting with "0"
/// (e.g. 0712345678) — PhoneNumberNormalizer on the backend still accepts
/// +255/255-prefixed forms for already-stored data, but new input is
/// restricted to this one shape so users get an immediate, consistent error
/// instead of a round-trip to the server.
final List<TextInputFormatter> tanzanianPhoneInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];

final RegExp _tanzanianPhonePattern = RegExp(r'^0[67]\d{8}$');

bool isValidTanzanianPhone(String value) => _tanzanianPhonePattern.hasMatch(value);

/// The backend always stores/returns phone numbers normalized to E.164
/// (+255XXXXXXXXX — see PhoneNumberNormalizer), but every input field now
/// only accepts the local 0XXXXXXXXX shape. Anywhere an already-stored
/// number is pre-filled into an editable field (e.g. editing a driver, or
/// showing a profile's current phone), it needs converting back to that
/// shape first — otherwise the field would show a value its own validator
/// immediately rejects.
String toLocalPhoneDisplay(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('255')) return '0${digits.substring(3)}';
  if (digits.length == 9) return '0$digits';
  return value;
}
