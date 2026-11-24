import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:proxypin/network/bin/listener.dart';
import 'package:proxypin/network/channel/channel.dart';
import 'package:proxypin/network/channel/channel_context.dart';
import 'package:proxypin/network/channel/host_port.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/http/http_headers.dart';

/// One captured exchange in "HTTP history".
class BurpItem {
  final int no;
  final HttpRequest request;
  HttpResponse? response;

  BurpItem(this.no, this.request);

  String get host => request.hostAndPort?.host ?? request.headers.host ?? '';

  bool get https => request.hostAndPort?.scheme == HostAndPort.httpsScheme;

  int get length => response?.body?.length ?? 0;

  int? get status => response?.status.code;
}

/// A Repeater tab.
class RepeaterTabData {
  String name;
  String raw;
  bool https;
  String? responseRaw;
  int? status;
  int? length;
  int? millis;

  RepeaterTabData(this.name, this.raw, this.https);
}

/// Shared state for the Burp-style screens.
class BurpState {
  static final BurpState instance = BurpState._();

  BurpState._() {
    listener = _BurpListener(this);
  }

  late final EventListener listener;

  final ValueNotifier<List<BurpItem>> history = ValueNotifier([]);
  final Map<String, BurpItem> _byId = {};
  int _counter = 0;
  static const int maxHistory = 3000;

  final ValueNotifier<List<RepeaterTabData>> repeaterTabs = ValueNotifier([]);
  final ValueNotifier<int> repeaterIndex = ValueNotifier(0);

  /// Pending request handed to Intruder (raw text + https flag).
  final ValueNotifier<RepeaterTabData?> intruderTarget = ValueNotifier(null);

  /// Tab switching request from other screens (0..5).
  final ValueNotifier<int> requestedTab = ValueNotifier(-1);

  // ---- scope / intercept filters ----
  final ValueNotifier<List<String>> scope = ValueNotifier([]);
  bool historyScopeOnly = false;
  bool interceptScopeOnly = false;
  bool skipStaticFiles = true;

  static const _staticExt = [
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.ico', '.css', '.js', '.woff', '.woff2', '.ttf', '.otf', '.mp4',
    '.mp3', '.map', '.bmp'
  ];

  bool inScope(String host) {
    if (scope.value.isEmpty) return true;
    final h = host.toLowerCase();
    for (var s in scope.value) {
      final p = s.trim().toLowerCase();
      if (p.isEmpty) continue;
      if (h == p || h.endsWith('.$p') || h.contains(p)) return true;
    }
    return false;
  }

  /// Used by the interceptor when "Intercept ALL" is ON.
  bool shouldIntercept(HttpRequest request) {
    final host = request.hostAndPort?.host ?? request.headers.host ?? '';
    if (interceptScopeOnly && !inScope(host)) return false;
    if (skipStaticFiles) {
      final path = (request.requestUri?.path ?? request.uri).toLowerCase();
      for (var e in _staticExt) {
        if (path.endsWith(e)) return false;
      }
    }
    return true;
  }

  void _onRequest(HttpRequest request) {
    if (request.method == HttpMethod.connect) return;
    final item = BurpItem(++_counter, request);
    _byId[request.requestId] = item;
    var list = history.value;
    if (list.length >= maxHistory) {
      final removed = list.first;
      _byId.remove(removed.request.requestId);
      list = list.sublist(1);
    }
    history.value = [...list, item];
  }

  void _onResponse(HttpResponse response) {
    final id = response.request?.requestId;
    if (id == null) return;
    final item = _byId[id];
    if (item != null) {
      item.response = response;
      history.value = List.of(history.value); // refresh
    }
  }

  void clearHistory() {
    _byId.clear();
    history.value = [];
  }

  // ---- navigation helpers ----
  void sendToRepeater(BurpItem item) {
    final tab = RepeaterTabData('${repeaterTabs.value.length + 1}', rawRequest(item.request), item.https);
    repeaterTabs.value = [...repeaterTabs.value, tab];
    repeaterIndex.value = repeaterTabs.value.length - 1;
    requestedTab.value = -1;
    requestedTab.value = 2;
  }

  void sendRequestToRepeater(HttpRequest request) {
    final https = request.hostAndPort?.scheme == HostAndPort.httpsScheme || request.requestUrl.startsWith('https');
    final tab = RepeaterTabData('${repeaterTabs.value.length + 1}', rawRequest(request), https);
    repeaterTabs.value = [...repeaterTabs.value, tab];
    repeaterIndex.value = repeaterTabs.value.length - 1;
    requestedTab.value = -1;
    requestedTab.value = 2;
  }

  void sendRequestToIntruder(HttpRequest request) {
    final https = request.hostAndPort?.scheme == HostAndPort.httpsScheme || request.requestUrl.startsWith('https');
    intruderTarget.value = RepeaterTabData('intruder', rawRequest(request), https);
    requestedTab.value = -1;
    requestedTab.value = 3;
  }

  // ---------------------------------------------------------------------------
  // Raw HTTP text <-> model
  // ---------------------------------------------------------------------------

  static String rawRequest(HttpRequest r) {
    String path;
    try {
      final uri = r.requestUri;
      if (uri != null) {
        final p = uri.path.isEmpty ? '/' : uri.path;
        path = '$p${uri.hasQuery ? '?${uri.query}' : ''}';
      } else {
        path = r.uri;
      }
    } catch (_) {
      path = r.uri;
    }
    final sb = StringBuffer('${r.method.name} $path ${r.protocolVersion == 'HTTP/2' ? 'HTTP/1.1' : r.protocolVersion}\r\n');
    var hasHost = false;
    r.headers.forEach((name, values) {
      if (name.toLowerCase() == 'host') hasHost = true;
      for (var v in values) {
        sb.write('$name: $v\r\n');
      }
    });
    if (!hasHost) {
      final h = r.hostAndPort?.host ?? '';
      if (h.isNotEmpty) sb.write('Host: $h\r\n');
    }
    sb.write('\r\n');
    sb.write(bodyText(r));
    return sb.toString();
  }

  static String rawResponse(HttpResponse r) {
    final sb = StringBuffer('${r.protocolVersion} ${r.status.code} ${r.status.reasonPhrase}\r\n');
    r.headers.forEach((name, values) {
      for (var v in values) {
        sb.write('$name: $v\r\n');
      }
    });
    sb.write('\r\n');
    sb.write(bodyText(r));
    return sb.toString();
  }

  static String bodyText(HttpMessage m) {
    try {
      final b = m.body;
      if (b == null || b.isEmpty) return '';
      return m.bodyAsString;
    } catch (_) {
      try {
        return utf8.decode(m.body ?? [], allowMalformed: true);
      } catch (_) {
        return '';
      }
    }
  }

  static (String head, String body) _split(String raw) {
    final text = raw.replaceAll('\r\n', '\n');
    final idx = text.indexOf('\n\n');
    if (idx < 0) return (text, '');
    return (text.substring(0, idx), text.substring(idx + 2));
  }

  /// Parse raw text into a request ready to be sent (full URL as uri).
  /// Throws FormatException on bad input.
  static HttpRequest parseRequest(String raw, {required bool https}) {
    final (head, body) = _split(raw);
    final lines = head.split('\n').where((e) => e.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw const FormatException('Empty request');

    final first = lines.first.trim().split(RegExp(r'\s+'));
    if (first.length < 2) throw const FormatException('Bad request line (METHOD /path HTTP/1.1)');
    final method = HttpMethod.valueOf(first[0]);
    final target = first[1];
    final version = first.length > 2 ? first[2] : 'HTTP/1.1';

    final headers = <MapEntry<String, String>>[];
    for (var l in lines.skip(1)) {
      final i = l.indexOf(':');
      if (i <= 0) continue;
      headers.add(MapEntry(l.substring(0, i).trim(), l.substring(i + 1).trim()));
    }
    String? host;
    for (var h in headers) {
      if (h.key.toLowerCase() == 'host') host = h.value;
    }

    String url;
    if (target.startsWith('http://') || target.startsWith('https://')) {
      url = target;
    } else {
      if (host == null || host.isEmpty) throw const FormatException('Missing Host header');
      url = '${https ? 'https' : 'http'}://$host${target.startsWith('/') ? target : '/$target'}';
    }

    final request = HttpRequest(method, url, protocolVersion: version.startsWith('HTTP/') ? version : 'HTTP/1.1');
    for (var h in headers) {
      final n = h.key.toLowerCase();
      if (n == 'content-length') continue; // recomputed
      request.headers.add(h.key, h.value);
    }
    if (body.isNotEmpty) {
      final bytes = utf8.encode(body);
      request.body = bytes;
      request.headers.set(HttpHeaders.CONTENT_LENGTH, '${bytes.length}');
    }
    request.hostAndPort = HostAndPort.of(url);
    return request;
  }

  /// Parse raw text into a response (used when editing intercepted responses).
  static HttpResponse parseResponse(String raw) {
    final (head, body) = _split(raw);
    final lines = head.split('\n').where((e) => e.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw const FormatException('Empty response');
    final first = lines.first.trim().split(RegExp(r'\s+'));
    if (first.length < 2) throw const FormatException('Bad status line (HTTP/1.1 200 OK)');
    final code = int.parse(first[1]);
    final reason = first.length > 2 ? first.sublist(2).join(' ') : null;
    final response = HttpResponse(HttpStatus.newStatus(code, reason),
        protocolVersion: first[0].startsWith('HTTP/') ? first[0] : 'HTTP/1.1');
    for (var l in lines.skip(1)) {
      final i = l.indexOf(':');
      if (i <= 0) continue;
      final name = l.substring(0, i).trim();
      if (name.toLowerCase() == 'content-length') continue;
      response.headers.add(name, l.substring(i + 1).trim());
    }
    final bytes = utf8.encode(body);
    response.body = bytes;
    response.headers.set(HttpHeaders.CONTENT_LENGTH, '${bytes.length}');
    return response;
  }
}

class _BurpListener extends EventListener {
  final BurpState state;

  _BurpListener(this.state);

  @override
  void onRequest(Channel channel, HttpRequest request) => state._onRequest(request);

  @override
  void onResponse(ChannelContext channelContext, HttpResponse response) => state._onResponse(response);
}
