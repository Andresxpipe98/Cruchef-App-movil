import 'package:cruchef/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows user-focused CruChef app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CruchefApp());

    expect(find.text('CruChef para clientes'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);
    expect(find.text('Favoritos'), findsWidgets);
  });
}
