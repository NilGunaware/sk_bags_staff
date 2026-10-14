import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../constants/api_endpoints.dart';
import '../../data/models/item_server_status.dart';
import 'local_item_sync_service.dart';

class ItemServerMonitor with WidgetsBindingObserver {
  ItemServerMonitor(this.service, {Future<WebSocket> Function(String)? connect})
    : _connect = connect ?? WebSocket.connect;

  final LocalItemSyncService service;
  final Future<WebSocket> Function(String) _connect;
  final Map<String, WebSocket> _sockets = {};
  int _generation = 0;
  bool _running = false;
  bool _disposed = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void _resume() {
    if (_running || _disposed) return;
    _running = true;
    final generation = ++_generation;
    for (final server in {
      ApiEndpoints.ahmLabel: ApiEndpoints.ahmItemsBaseUrl,
      ApiEndpoints.bhuLabel: ApiEndpoints.bhuItemsBaseUrl,
    }.entries) {
      service.serverStatuses[server.key] =
          service.serverStatuses[server.key] == ItemServerStatus.checking
          ? ItemServerStatus.checking
          : ItemServerStatus.reconnecting;
      unawaited(_monitor(server.key, server.value, generation));
    }
  }

  bool _active(int generation) => _running && generation == _generation;

  Future<void> _monitor(String name, String baseUrl, int generation) async {
    var retrySeconds = 2;
    while (_active(generation)) {
      WebSocket? socket;
      try {
        final uri = Uri.parse('$baseUrl/ws/health');
        // A timed-out connect may still finish: close it if its generation expired.
        final connection = _connect(
          uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws').toString(),
        );
        var expired = false;
        unawaited(
          connection.then((lateSocket) {
            if (expired || !_active(generation)) unawaited(lateSocket.close());
          }, onError: (Object _) {}),
        );
        try {
          socket = await connection.timeout(const Duration(seconds: 5));
        } finally {
          expired = socket == null;
        }
        if (!_active(generation)) {
          await socket.close();
          return;
        }
        _sockets[name] = socket;
        socket.pingInterval = const Duration(seconds: 5);
        await for (final message in socket.timeout(
          const Duration(seconds: 15),
        )) {
          if (!_active(generation)) break;
          final data = jsonDecode(message as String);
          if (data is! Map || data['type'] != 'health') continue;
          service.serverStatuses[name] = data['databaseReady'] == false
              ? ItemServerStatus.databaseUnavailable
              : data['status'] == 'ok'
              ? ItemServerStatus.online
              : ItemServerStatus.reconnecting;
          retrySeconds = 2;
        }
      } catch (_) {
        // Older desktop builds and routers without WebSocket support use HTTP health.
      } finally {
        if (identical(_sockets[name], socket)) _sockets.remove(name);
        await socket?.close();
      }
      if (!_active(generation)) return;
      service.serverStatuses[name] = ItemServerStatus.reconnecting;
      final status = await service.checkServerHealth(name, baseUrl);
      if (!_active(generation)) return;
      service.serverStatuses[name] = status;
      final waitSeconds = status == ItemServerStatus.online ? 30 : retrySeconds;
      // Short waits let backgrounding/disposal stop reconnect work promptly.
      for (
        var second = 0;
        second < waitSeconds && _active(generation);
        second++
      ) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      retrySeconds = (retrySeconds * 2).clamp(2, 30);
    }
  }

  void _pause() {
    _running = false;
    ++_generation;
    for (final socket in _sockets.values) {
      unawaited(socket.close());
    }
    _sockets.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _pause();
    }
  }

  void dispose() {
    _disposed = true;
    _pause();
    WidgetsBinding.instance.removeObserver(this);
  }
}
