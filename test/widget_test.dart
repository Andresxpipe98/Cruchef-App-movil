import 'package:cruchef/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows customer login shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLogin: (String email, String password) async {},
          isBusy: false,
          errorMessage: null,
        ),
      ),
    );

    expect(find.text('CruChef'), findsWidgets);
    expect(find.text('Acceso de clientes'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
