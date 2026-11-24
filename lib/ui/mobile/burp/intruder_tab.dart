import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:proxypin/network/http/http_client.dart';
import 'package:proxypin/ui/mobile/burp/burp_state.dart';
import 'package:proxypin/ui/mobile/burp/burp_widgets.dart';

/// Lightweight Intruder: mark §payload§ positions in the raw request, run a
/// payload list through them (sniper = each position in turn), see per-row results.
class IntruderTab extends StatefulWidget {
  const IntruderTab({super.key});

  @override
  State<IntruderTab> createState() => _IntruderTabState();
}

class _IntruderRow {
  final String payload;
  int? status;
  int? length;
  int? millis;
  String? error;

  _IntruderRow(this.payload);
}

class _IntruderTabState extends State<IntruderTab> {
  final state = BurpState.instance;
  final editor = TextEditingController(
      text: 'GET /search?q=§test§ HTTP/1.1\r\nHost: example.com\r\nUser-Agent: Mozilla/5.0\r\n\r\n');
  final payloads = TextEditingController(text: 'admin\nadministrator\ntest\n1\n0');
  bool https = true;
  bool running = false;
  bool stopRequested = false;
  int concurrency = 5;
  final List<_IntruderRow> rows = [];

  @override
  void initState() {
    super.initState();
    state.intruderTarget.addListener(_onTarget);
    _onTarget();
  }

  @override
  void dispose() {
    state.intruderTarget.removeListener(_onTarget);
    editor.dispose();
    payloads.dispose();
    super.dispose();
  }

  void _onTarget() {
    final t = state.intruderTarget.value;
    if (t == null) return;
    setState(() {
      editor.text = t.raw;
      https = t.https;
    });
    state.intruderTarget.value = null;
  }

  Future<void> _run() async {
    if (running) return;
    final list = payloads.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty || !editor.text.contains('§')) {
      toast(context, 'Mark a position with § § and add at least 1 payload');
      return;
    }
    setState(() {
      running = true;
      stopRequested = false;
      rows
        ..clear()
        ..addAll(list.map(_IntruderRow.new));
    });

    final template = editor.text;
    var next = 0;
    Future<void> worker() async {
      while (true) {
        if (stopRequested) return;
        final i = next++;
        if (i >= rows.length) return;
        final row = rows[i];
        final raw = _applyPayload(template, row.payload);
        final sw = Stopwatch()..start();
        try {
          final req = BurpState.parseRequest(raw, https: https);
          final res = await HttpClients.proxyRequest(req, timeout: const Duration(seconds: 15));
          sw.stop();
          row.status = res.status.code;
          row.length = res.body?.length ?? 0;
          row.millis = sw.elapsedMilliseconds;
        } catch (e) {
          sw.stop();
          row.error = '$e';
          row.millis = sw.elapsedMilliseconds;
        }
        if (mounted) setState(() {});
      }
    }

    await Future.wait(List.generate(concurrency.clamp(1, 10), (_) => worker()));
    if (mounted) setState(() => running = false);
  }

  String _applyPayload(String template, String payload) {
    // §x§ -> payload (URL-encoded if it sits inside the request line / query)
    final encoded = Uri.encodeComponent(payload);
    final firstLineEnd = template.indexOf('\n');
    final requestLine = firstLineEnd < 0 ? template : template.substring(0, firstLineEnd);
    if (requestLine.contains('§')) {
      final newFirst = requestLine.replaceAll(RegExp('§[^§]*§'), encoded);
      return newFirst + template.substring(firstLineEnd < 0 ? template.length : firstLineEnd);
    }
    return template.replaceAll(RegExp('§[^§]*§'), payload);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          child: Row(children: [
            const Text('Mark payload position with § §', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            const Text('HTTPS', style: TextStyle(fontSize: 11)),
            Switch(value: https, onChanged: running ? null : (v) => setState(() => https = v)),
          ])),
      SizedBox(height: 90, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: RawEditor(controller: editor))),
      Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          child: Row(children: [
            const Text('Payloads (one per line)', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            SizedBox(
                width: 110,
                child: Row(children: [
                  const Text('Threads', style: TextStyle(fontSize: 11)),
                  Expanded(
                      child: Slider(
                          value: concurrency.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$concurrency',
                          onChanged: running ? null : (v) => setState(() => concurrency = v.round()))),
                ])),
          ])),
      SizedBox(height: 70, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: RawEditor(controller: payloads))),
      Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: FilledButton.icon(
                    onPressed: running ? null : _run,
                    icon: running
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt, size: 16),
                    label: Text(running ? 'Running…' : 'Start attack'))),
            if (running) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => setState(() => stopRequested = true), child: const Text('Stop')),
            ]
          ])),
      const Divider(height: 0),
      Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Results appear here', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: SizedBox(width: 24, child: Text('$i', style: const TextStyle(fontSize: 11))),
                      title: Text(r.payload, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: r.error != null
                          ? Text(r.error!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 11))
                          : null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (r.status != null)
                          Text('${r.status}', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor(r.status))),
                        if (r.length != null) Text('  ${r.length}b', style: const TextStyle(fontSize: 11)),
                        if (r.millis != null) Text('  ${r.millis}ms', style: const TextStyle(fontSize: 11)),
                      ]),
                    );
                  })),
    ]);
  }
}
