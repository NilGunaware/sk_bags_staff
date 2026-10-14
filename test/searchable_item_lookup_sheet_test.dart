import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sk_bags_staff/core/services/local_item_sync_service.dart';
import 'package:sk_bags_staff/modules/home/searchable_item_lookup_sheet.dart';

http.Response response(String name, int quantity) => http.Response(
  jsonEncode({
    'data': [
      {'itemCode': '36086', 'itemName': name, 'itemQuantity': quantity},
    ],
  }),
  200,
);

void main() {
  tearDown(() => Get.reset());

  for (final unavailable in [false, true]) {
    testWidgets('empty results distinguish unavailable=$unavailable', (
      tester,
    ) async {
      final client = MockClient(
        (_) async => unavailable
            ? http.Response('{}', 503)
            : http.Response('{"data":[]}', 200),
      );
      Get.put(LocalItemSyncService(client: client));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SearchableItemLookupSheet())),
      );
      await tester.enterText(find.byType(TextField), 'Unknown');
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(
        find.text(
          unavailable
              ? 'Search incomplete. Please try again.'
              : 'No item found for "Unknown".',
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      client.close();
    });
  }

  testWidgets(
    'typing does not search; submit shows progressive combined results',
    (tester) async {
      final replies = {
        8008: Completer<http.Response>(),
        8009: Completer<http.Response>(),
      };
      var requests = 0;
      final client = MockClient((request) {
        requests++;
        return replies[request.url.port]!.future;
      });
      Get.put(LocalItemSyncService(client: client));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SearchableItemLookupSheet())),
      );
      await tester.enterText(find.byType(TextField), 'Carnaby');
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 0);
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(requests, 2);
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(requests, 2);
      replies[8009]!.complete(response('Carnaby', 5));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Carnaby',
        ),
        findsOneWidget,
      );
      expect(find.text('5 qty'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      replies[8008]!.complete(response('Carnaby', 8));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Carnaby',
        ),
        findsOneWidget,
      );
      expect(find.text('13 qty'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      client.close();
    },
  );

  testWidgets(
    'edited query ignores old responses and keyboard submits new search',
    (tester) async {
      final oldReply = Completer<http.Response>();
      final newReply = Completer<http.Response>();
      var requests = 0;
      final client = MockClient((request) {
        requests++;
        return request.url.queryParameters['search'] == 'Old'
            ? oldReply.future
            : newReply.future;
      });
      Get.put(LocalItemSyncService(client: client));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SearchableItemLookupSheet())),
      );
      await tester.enterText(find.byType(TextField), 'Old');
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'New');
      await tester.pump();
      oldReply.complete(response('Old item', 5));
      await tester.pump();
      expect(find.text('Old item'), findsNothing);
      expect(requests, 2);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(requests, 4);
      newReply.complete(response('New item', 7));
      await tester.pump();
      expect(find.text('New item'), findsOneWidget);
      expect(find.text('14 qty'), findsOneWidget);
      client.close();
    },
  );
}
