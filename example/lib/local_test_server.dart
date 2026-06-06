import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class LocalTestServer {
  LocalTestServer._();
  static final LocalTestServer instance = LocalTestServer._();

  HttpServer? _server;
  int _requestCount = 0;

  final ValueNotifier<List<String>> logs = ValueNotifier([]);

  bool get isRunning => _server != null;

  Future<void> start({int port = 8099}) async {
    if (isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      final localIp = await getLocalIp();

      _addLog('╔══════════════════════════════════════════════════════╗');
      _addLog('║  Internal Tracelet Test Server                      ║');
      _addLog('╠══════════════════════════════════════════════════════╣');
      _addLog('║  Listening on: http://$localIp:$port/locations');
      _addLog('║  Use this URL in your Tracelet HttpConfig.          ║');
      _addLog('╚══════════════════════════════════════════════════════╝');
      _addLog('');
      _addLog('Waiting for location sync requests...');
      _addLog('');

      _server!.listen(_handleRequest);
    } catch (e) {
      _addLog('Failed to start server: $e');
    }
  }

  Future<void> stop() async {
    if (!isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _addLog('Server stopped.');
  }

  void clearLogs() {
    logs.value = [];
  }

  void _addLog(String log) {
    logs.value = [...logs.value, '[$_time] $log'];
  }

  String get _time {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _requestCount++;
    final reqId = _requestCount;

    if (request.method != 'POST') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..close();
      return;
    }

    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;

      _addLog('── Request #$reqId ──');

      if (data.containsKey('locations')) {
        final locs = data['locations'] as List;
        _addLog('Received ${locs.length} locations');
        for (final l in locs) {
          final lat = l['coords']['latitude'];
          final lng = l['coords']['longitude'];
          _addLog('  📍 $lat, $lng');
        }
      } else {
        _addLog('Custom Payload: $data');
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true}))
        ..close();

      _addLog('→ 200 OK');
      _addLog('');
    } catch (e) {
      _addLog('Error processing request: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..close();
    }
  }

  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        if (iface.name == 'en0' || iface.name == 'wlan0') {
          return iface.addresses.first.address;
        }
      }
      if (interfaces.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '0.0.0.0';
  }
}
