import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sk_bags_staff/core/constants/api_endpoints.dart';
import 'package:sk_bags_staff/core/services/local_item_sync_service.dart';
import 'package:sk_bags_staff/data/models/order_models.dart';

http.Response itemResponse(double quantity, {bool includeSecondItem = false}) {
  return http.Response(
    jsonEncode({
      'data': [
        {'itemCode': '36086', 'itemName': 'Carnaby', 'itemQuantity': quantity},
        if (includeSecondItem)
          {'itemCode': '40085', 'itemName': 'Foam', 'itemQuantity': 2},
      ],
    }),
    200,
  );
}

void main() {
  for (final fastPort in [8008, 8009]) {
    test(
      'port $fastPort publishes before the other server and merges once',
      () async {
        final replies = {
          8008: Completer<http.Response>(),
          8009: Completer<http.Response>(),
        };
        final client = MockClient(
          (request) => replies[request.url.port]!.future,
        );
        final service = LocalItemSyncService(client: client);
        final snapshots = <MergedItemPage>[];
        final first = Completer<void>();
        var finished = false;
        final result = service
            .searchItems(
              page: 1,
              pageSize: 20,
              query: 'Carnaby',
              onPartialResult: (page) {
                snapshots.add(page);
                if (!first.isCompleted) first.complete();
              },
            )
            .then((page) {
              finished = true;
              return page;
            });

        replies[fastPort]!.complete(itemResponse(5));
        await first.future;
        expect(finished, isFalse);
        expect(snapshots.single.items.single.totalQuantity, 5);
        expect(snapshots.single.warnings, isEmpty);

        replies[fastPort == 8008 ? 8009 : 8008]!.complete(
          itemResponse(8, includeSecondItem: true),
        );
        final page = await result;
        expect(page.items, hasLength(2));
        expect(page.items.first.totalQuantity, 13);
        expect(
          page.items.first.serverQuantities.values,
          unorderedEquals([5.0, 8.0]),
        );
        expect(snapshots, hasLength(2));
        expect(snapshots.last.items.first.totalQuantity, 13);
        client.close();
      },
    );
  }

  test(
    'failed server retains online results and reports its warning',
    () async {
      final offline = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.port == 8009) return offline.future;
        return itemResponse(533);
      });
      final service = LocalItemSyncService(client: client);
      final first = Completer<MergedItemPage>();
      final result = http.runWithClient(
        () => service.searchItems(
          page: 1,
          pageSize: 20,
          query: 'Carnaby',
          onPartialResult: (page) {
            if (!first.isCompleted) first.complete(page);
          },
        ),
        () => client,
      );
      expect((await first.future).items.single.totalQuantity, 533);
      offline.completeError(http.ClientException('Connection refused'));
      final page = await result;
      expect(page.items.single.totalQuantity, 533);
      expect(page.warnings.single, contains(ApiEndpoints.bhuLabel));
      client.close();
    },
  );
}
