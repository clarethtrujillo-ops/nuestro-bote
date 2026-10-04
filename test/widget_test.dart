import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_bote/app/app.dart';

void main() {
  testWidgets('muestra y conecta las acciones de bienvenida', (tester) async {
    await tester.pumpWidget(const NuestroBoteApp());

    expect(find.text('Todo lo que sueñan,\nen un solo lugar.'), findsOneWidget);
    expect(find.text('Crear nuestro bote'), findsOneWidget);
    expect(find.text('Tengo una invitación'), findsOneWidget);

    await tester.tap(find.text('Crear nuestro bote'));
    await tester.pumpAndSettle();

    expect(find.text('El bote empieza\ncon los dos'), findsOneWidget);
    expect(find.text('LUNA27'), findsOneWidget);
    expect(find.text('Compartir invitación'), findsOneWidget);
  });
}
