import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sk_bags_staff/core/constants/api_endpoints.dart';
import 'package:sk_bags_staff/core/services/item_server_monitor.dart';
import 'package:sk_bags_staff/core/services/local_item_sync_service.dart';
import 'package:sk_bags_staff/data/models/item_server_status.dart';

class TestSocket extends Stream<dynamic> implements WebSocket {
  final messages = StreamController<dynamic>();
  bool closed = false;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => messages.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  set pingInterval(Duration? value) {}

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    unawaited(messages.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('heartbeats update each server and lifecycle reconnects both', (
    tester,
  ) async {
    final service = LocalItemSyncService();
    final sockets = <int, TestSocket>{};
    var connections = 0;
    final monitor = ItemServerMonitor(
      service,
      connect: (url) async {
        connections++;
        final socket = TestSocket();
        sockets[Uri.parse(url).port] = socket;
        return socket;
      },
    );
    monitor.start();
    await tester.pump();
    sockets[8008]!.messages.add(
      jsonEncode({'type': 'health', 'status': 'ok', 'databaseReady': true}),
    );
    sockets[8009]!.messages.add(
      jsonEncode({
        'type': 'health',
        'status': 'degraded',
        'databaseReady': false,
      }),
    );
    await tester.pump();
    expect(
      service.serverStatuses[ApiEndpoints.ahmLabel],
      ItemServerStatus.online,
    );
    expect(
      service.serverStatuses[ApiEndpoints.bhuLabel],
      ItemServerStatus.databaseUnavailable,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(sockets.values.every((socket) => socket.closed), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(connections, 4);
    monitor.dispose();
    await tester.pump();
  });

  testWidgets('unsupported WebSockets fall back to HTTP independently', (
    tester,
  ) async {
    final slow = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.port == 8009) return slow.future;
      return http.Response('{"status":"ok"}', 200);
    });
    final service = LocalItemSyncService(client: client);
    final monitor = ItemServerMonitor(
      service,
      connect: (_) async => throw const SocketException('unsupported'),
    );
    monitor.start();
    await tester.pump();
    expect(
      service.serverStatuses[ApiEndpoints.ahmLabel],
      ItemServerStatus.online,
    );
    expect(
      service.serverStatuses[ApiEndpoints.bhuLabel],
      ItemServerStatus.reconnecting,
    );
    slow.complete(
      http.Response('{"status":"degraded","databaseReady":false}', 200),
    );
    await tester.pump();
    expect(
      service.serverStatuses[ApiEndpoints.bhuLabel],
      ItemServerStatus.databaseUnavailable,
    );
    monitor.dispose();
    await tester.pump(const Duration(seconds: 1));
    client.close();
  });
}
