import 'package:flutter_application_4/main.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
//import 'package:flutter_application_3/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Construye la app
    await tester.pumpWidget(const MyApp());

    // Verifica que existe el tab Inicio
    expect(find.text('Inicio'), findsOneWidget);

    // Verifica que existe el tab Perfil
    expect(find.text('Perfil'), findsOneWidget);
  });
}
