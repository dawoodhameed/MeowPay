import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meowpay/api/meowpay_api.dart';
import 'package:meowpay/screens/send_treats_screen.dart';
import 'package:meowpay/state/send_controller.dart';

const _catsJson = '''
[
  {"id":"c1","name":"Whiskers","avatarUrl":null,"walletId":"w1","balance":100},
  {"id":"c2","name":"Mittens","avatarUrl":null,"walletId":"w2","balance":50}
]
''';

Widget _app(SendController controller) =>
    MaterialApp(home: SendTreatsScreen(controller: controller));

SendController _controller(
  Future<http.Response> Function(http.Request) handler,
) =>
    SendController(api: MeowPayApi(client: MockClient(handler), baseUrl: ''));

void main() {
  testWidgets('shows the sender balance and both cats', (tester) async {
    await tester.pumpWidget(
      _app(_controller((_) async => http.Response(_catsJson, 200))),
    );
    await tester.pumpAndSettle();

    expect(find.text('MeowPay'), findsOneWidget);
    // The balance card composes its figure from spans, so the finder must descend
    // into the RichText and match on a substring rather than the whole widget.
    expect(
      find.textContaining('100', findRichText: true),
      findsWidgets,
      reason: 'sender balance should be displayed',
    );
    expect(find.text('100 treats'), findsOneWidget); // the picker chip
    expect(find.text('Whiskers'), findsWidgets);
    expect(find.text('Mittens'), findsWidgets);
    // The button names the consequence, not just the action.
    expect(find.text('Send to Mittens'), findsOneWidget);
  });

  testWidgets('blocks a send that exceeds the balance', (tester) async {
    var postCount = 0;
    await tester.pumpWidget(
      _app(_controller((request) async {
        if (request.method == 'POST') postCount++;
        return http.Response(_catsJson, 200);
      })),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Send to Mittens'));
    await tester.pumpAndSettle();

    expect(find.text('Only 100 treats available'), findsOneWidget);
    // Validation must stop the request, not merely colour the field.
    expect(postCount, 0);
  });

  testWidgets('reports success with the remaining balance', (tester) async {
    await tester.pumpWidget(
      _app(_controller((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'id': 't1', 'amount': 25, 'senderBalanceAfter': 75}),
            201,
          );
        }
        return http.Response(_catsJson, 200);
      })),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '25');
    await tester.tap(find.text('Send to Mittens'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sent 25 treats to Mittens'), findsOneWidget);
    expect(find.textContaining('75 left'), findsOneWidget);
  });

  testWidgets('surfaces the API refusal in the user\'s own terms', (tester) async {
    await tester.pumpWidget(
      _app(_controller((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'type': 'https://meowpay.co/problems/insufficient-funds',
              'title': 'Not enough treats',
              'balance': 12,
            }),
            422,
          );
        }
        return http.Response(_catsJson, 200);
      })),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '50');
    await tester.tap(find.text('Send to Mittens'));
    await tester.pumpAndSettle();

    // The server's own title is not shown; the message is rewritten for the person
    // holding the phone, using the balance the API supplied.
    expect(find.textContaining('only 12 left'), findsOneWidget);
  });

  testWidgets('offers a retry when the API is unreachable', (tester) async {
    await tester.pumpWidget(
      _app(_controller((_) async => throw Exception('no route to host'))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cannot reach MeowPay'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
