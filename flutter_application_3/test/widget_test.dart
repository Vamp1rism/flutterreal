import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_3/main.dart';

void main() {
  testWidgets('FocusNotesProApp renderiza e permite criar tópico', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusNotesProApp());

    // Verifica elementos iniciais da interface
    expect(find.text('Focus Notes Pro'), findsOneWidget);
    expect(find.text('Tópicos de Estudo'), findsOneWidget);
    expect(find.text('Revisão Geral'), findsWidgets);

    // Testa criação de um novo tópico
    await tester.enterText(
      find.widgetWithText(TextField, 'Novo tópico (ex: Química Orgânica)...'),
      'Cálculo I',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
    await tester.pump();

    expect(find.text('Cálculo I'), findsWidgets);
  });
}