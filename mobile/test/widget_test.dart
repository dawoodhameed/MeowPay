import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meowpay/api/meowpay_api.dart';
import 'package:meowpay/screens/home_screen.dart';
import 'package:meowpay/screens/sign_in_screen.dart';
import 'package:meowpay/state/send_controller.dart';
import 'package:meowpay/theme.dart';

const _catsJson = '''
[
  {"id":"c1","name":"Whiskers","accountNumber":"10000001","avatarUrl":null,"walletId":"w1","balance":100},
  {"id":"c2","name":"Mittens","accountNumber":"10000002","avatarUrl":null,"walletId":"w2","balance":50}
]
''';

const _mittensJson =
    '{"id":"c2","name":"Mittens","accountNumber":"10000002","avatarUrl":null,"walletId":"w2","balance":50}';

SendController _controller(
  Future<http.Response> Function(http.Request) handler,
) =>
    SendController(api: MeowPayApi(client: MockClient(handler), baseUrl: ''));

Future<http.Response> _happyPath(http.Request request) async {
  if (request.url.path.contains('by-account')) {
    return http.Response(_mittensJson, 200);
  }
  if (request.method == 'POST') {
    return http.Response(
      jsonEncode({'id': 't1', 'amount': 25, 'senderBalanceAfter': 75}),
      201,
    );
  }
  return http.Response(_catsJson, 200);
}

Widget _wrap(Widget child) => MaterialApp(theme: meowTheme(), home: child);

void main() {
  group('sign-in screen', () {
    testWidgets('lists every cat with its account number', (tester) async {
      final c = _controller(_happyPath);
      // Loaded before pumping: this test renders the screen directly, so nothing is
      // listening to the controller to rebuild it, and the loading spinner would
      // otherwise animate forever and hang pumpAndSettle.
      await c.loadCats();
      await tester.pumpWidget(_wrap(SignInScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text("Who's paying?"), findsOneWidget);
      expect(find.text('Whiskers'), findsOneWidget);
      // Grouped for reading aloud, not printed as a raw run of digits.
      expect(find.text('1000 0001'), findsOneWidget);
      expect(find.text('1000 0002'), findsOneWidget);
    });
  });

  group('home screen', () {
    Future<SendController> signedIn(WidgetTester tester) async {
      final c = _controller(_happyPath);
      await c.loadCats();
      c.signIn(c.cats.first);
      await tester.pumpWidget(_wrap(HomeScreen(controller: c)));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('shows the balance and the signed-in cat\'s own account number',
        (tester) async {
      await signedIn(tester);

      expect(find.textContaining('100', findRichText: true), findsWidgets);
      expect(find.text('1000 0001'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('rejects a short account number without calling the API',
        (tester) async {
      var lookups = 0;
      final c = _controller((request) async {
        if (request.url.path.contains('by-account')) lookups++;
        return _happyPath(request);
      });
      await c.loadCats();
      c.signIn(c.cats.first);
      await tester.pumpWidget(_wrap(HomeScreen(controller: c)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Account numbers are 8 digits'), findsOneWidget);
      expect(lookups, 0);
    });

    testWidgets('confirms the payee by name before asking for an amount',
        (tester) async {
      await signedIn(tester);

      await tester.enterText(find.byType(TextField), '10000002');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The whole reason the steps are split: the sender sees who they are paying.
      expect(find.text('SENDING TO'), findsOneWidget);
      expect(find.text('Mittens'), findsOneWidget);
      expect(find.text('Send to Mittens'), findsOneWidget);
    });

    testWidgets('completes a send and reports the remaining balance',
        (tester) async {
      await signedIn(tester);

      await tester.enterText(find.byType(TextField), '10000002');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '25');
      await tester.tap(find.text('Send to Mittens'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sent 25 treats to Mittens'), findsOneWidget);
      expect(find.textContaining('75 left'), findsOneWidget);
    });

    testWidgets('blocks an amount above the balance', (tester) async {
      var posts = 0;
      final c = _controller((request) async {
        if (request.method == 'POST') posts++;
        return _happyPath(request);
      });
      await c.loadCats();
      c.signIn(c.cats.first);
      await tester.pumpWidget(_wrap(HomeScreen(controller: c)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '10000002');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '500');
      await tester.tap(find.text('Send to Mittens'));
      await tester.pumpAndSettle();

      expect(find.text('Only 100 treats available'), findsOneWidget);
      // Validation must stop the request, not merely colour the field.
      expect(posts, 0);
    });
  });
}
