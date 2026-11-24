import 'package:flutter/foundation.dart';
import 'package:proxypin/network/components/request_breakpoint.dart';
import 'package:proxypin/network/http/http.dart';

/// A request (or response) that is paused by "Intercept ON" and waits for the user.
class PendingIntercept {
  final String requestId;
  final HttpRequest request;
  final HttpResponse? response; // non-null => this is a paused response
  final DateTime time = DateTime.now();

  PendingIntercept({required this.requestId, required this.request, this.response});

  bool get isResponse => response != null;
}

/// Burp-style intercept queue.
class InterceptQueue {
  static final InterceptQueue instance = InterceptQueue._();

  InterceptQueue._();

  final ValueNotifier<List<PendingIntercept>> items = ValueNotifier([]);

  void add(PendingIntercept item) {
    items.value = [...items.value, item];
  }

  void _remove(PendingIntercept item) {
    items.value = items.value.where((e) => !identical(e, item)).toList();
  }

  /// Forward. [modifiedRequest]/[modifiedResponse] null => forward unchanged.
  void forward(PendingIntercept item, {HttpRequest? modifiedRequest, HttpResponse? modifiedResponse}) {
    _remove(item);
    if (item.isResponse) {
      RequestBreakpointInterceptor.instance.resumeResponse(item.requestId, modifiedResponse ?? item.response!.copy());
    } else {
      RequestBreakpointInterceptor.instance.resumeRequest(item.requestId, modifiedRequest ?? item.request.copy());
    }
  }

  /// Drop: request is never sent / response never delivered.
  void drop(PendingIntercept item) {
    _remove(item);
    if (item.isResponse) {
      RequestBreakpointInterceptor.instance.resumeResponse(item.requestId, null);
    } else {
      RequestBreakpointInterceptor.instance.resumeRequest(item.requestId, null);
    }
  }

  void forwardAll() {
    for (var item in List.of(items.value)) {
      forward(item);
    }
  }

  void dropAll() {
    for (var item in List.of(items.value)) {
      drop(item);
    }
  }

  /// Used when Intercept is turned OFF: everything continues exactly as if never intercepted.
  void releaseAll() => forwardAll();
}
