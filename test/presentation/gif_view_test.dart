import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_workout_app/presentation/widgets/gif_view.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 200, height: 200, child: child))),
    );

void main() {
  group('GifView (Requirements 2.2, 2.3, 2.4, 5.6)', () {
    testWidgets('exibe indicador de carregamento enquanto o GIF carrega '
        '(Req 2.2)', (tester) async {
      await tester.pumpWidget(
        _wrap(const GifView(gifUrl: 'https://example.com/a.gif')),
      );
      // Antes de resolver a imagem, o placeholder de carregamento é exibido.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('expõe semanticLabel quando fornecido', (tester) async {
      await tester.pumpWidget(
        _wrap(const GifView(
          gifUrl: 'https://example.com/a.gif',
          semanticLabel: 'Demonstração do supino',
        )),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel('Demonstração do supino'),
        findsOneWidget,
      );
    });

    testWidgets('renderiza sem exceções com um onRetry fornecido', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _wrap(GifView(
          gifUrl: 'https://example.com/a.gif',
          onRetry: () => retried++,
        )),
      );
      await tester.pump();
      // O widget monta corretamente; o callback de retry está disponível para
      // o estado de erro (acionado quando o carregamento do GIF falha).
      expect(find.byType(GifView), findsOneWidget);
      expect(retried, 0);
    });
  });
}
