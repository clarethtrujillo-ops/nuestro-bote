import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_bote/features/connection/domain/validators/invitation_code_validator.dart';

void main() {
  group('InvitationCodeValidator', () {
    test('acepta seis caracteres alfanuméricos', () {
      expect(InvitationCodeValidator.isValid('LUNA27'), isTrue);
    });

    test('rechaza códigos incompletos', () {
      expect(InvitationCodeValidator.isValid('LUNA'), isFalse);
    });

    test('rechaza caracteres especiales', () {
      expect(InvitationCodeValidator.isValid('LUN@27'), isFalse);
    });
  });
}
