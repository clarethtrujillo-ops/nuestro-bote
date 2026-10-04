import 'package:flutter/foundation.dart';

import '../../domain/validators/invitation_code_validator.dart';

class ConnectionController extends ChangeNotifier {
  String _code = '';
  bool _isLoading = false;

  String get code => _code;
  bool get isLoading => _isLoading;
  bool get canConnect => InvitationCodeValidator.isValid(_code);

  void updateCode(String value) {
    _code = value.toUpperCase();
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
