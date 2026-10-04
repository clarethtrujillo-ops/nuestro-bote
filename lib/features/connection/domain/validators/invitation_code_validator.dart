import '../../../../core/constants/app_constants.dart';

abstract final class InvitationCodeValidator {
  static final _pattern = RegExp(r'^[A-Z0-9]{6}$');

  static bool isValid(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.length == AppConstants.invitationCodeLength &&
        _pattern.hasMatch(normalized);
  }
}
