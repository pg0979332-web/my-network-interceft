import 'package:flutter/material.dart';
import 'package:proxypin/network/http/http_client.dart';
import 'package:proxypin/ui/mobile/burp/burp_state.dart';
import 'package:proxypin/ui/mobile/burp/burp_widgets.dart';

/// Burp Repeater: edit a raw request, Send, inspect the raw response. Multiple tabs.
class RepeaterTab extends StatefulWidget {
  const RepeaterTab({super.key});

  @override
  State<RepeaterTab> createState() => _RepeaterTabState();
}

class _RepeaterTabState extends State<RepeaterTab> {
  final state = BurpState.instance;
  final editor = TextEditingController();
  bool sending = false;
  int _loadedIndex = -1;
  int _loadedCount = -1;

  @override
  void initState() {
    super.initState();
    state.repeaterTabs.addListener(_sync);
    state.repeaterIndex.addListener(_sync);
    editor.addListener(() {
      final t = _current;
      if (t != null && _loadedIndex == state.repeaterIndex.value) t.raw = editor.text;
    });
    _sync();
  }

  @override
  void dispose() {
    state.repeaterTabs.removeListener(_sync);
    state.repeaterIndex.removeListener(_sync);
    editor.dispose();
    super.dispose();
  }

  RepeaterTabData? get _current {
    final list = state.repeaterTabs.value;
    final i = state.repeaterIndex.value;
    if (i < 0 || i >= list.length) return null;
    return list[i];
  }

  void _sync() {
    final list = state.repeaterTabs.value;
    final i = state.repeaterIndex.value;
    if (i != _loadedIndex || list.length != _loadedCount) {
      _loadedIndex = -1; // block listener while swapping text
      editor.text = (i >= 0 && i < list.length) ? list[i].raw : '';
      _loadedIndex = i;
      _loadedCount = list.length;
    }
    if (mounted) setState(() {});
  }

  void _newTab() {
    final tab = RepeaterTabData('${state.repeaterTabs.value.length + 1}',
        'GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: Mozilla/5.0\r\nAccept: */*\r\n\r\n', true);
    state.repeaterTabs.value = [...state.repeaterTabs.value, tab];
    state.repeaterIndex.value = state.repeaterTabs.value.length - 1;
  }

  void _closeTab() {
    final list = List<RepeaterTabData>.of(state.repeaterTabs.value);
    final i = state.repeaterIndex.value;
    if (i < 0 || i >= list.length) return;
    list.removeAt(i);
    state.repeaterTabs.value = list;
    state.repeaterIndex.value = list.isEmpty ? 0 : (i >= list.length ? list.length - 1 : i);
  }

  Future<void> _send() async {
    final tab = _current;
    if (tab == null || sending) return;
    tab.raw = editor.text;
    setState(() => sending = true);
    final sw = Stopwatch()..start();
    try {
      final req = BurpState.parseRequest(tab.raw, https: tab.https);
      final res = await HttpClients.proxyRequest(req, timeout: const Duration(seconds: 30));
      sw.stop();
      tab.responseRaw = BurpState.rawResponse(res);
      tab.status = res.status.code;
      tab.length = res.body?.length ?? 0;
      tab.millis = sw.elapsedMilliseconds;
    } catch (e) {
      sw.stop();
      tab.responseRaw = 'Error: $e';
      tab.status = null;
      tab.length = null;
      tab.millis = sw.elapsedMilliseconds;
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = state.repeaterTabs.value;
    final tab = _current;

    if (tabs.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('No Repeater tabs', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _newTab, child: const Text('New request')),
        const SizedBox(height: 4),
        const Text('or use "Send to Repeater" from History / Intercept',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]));
    }

    return Column(children: [
      SizedBox(
          height: 40,
          child: Row(children: [
            Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    children: [
                  for (var i = 0; i < tabs.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(tabs[i].name),
                            selected: i == state.repeaterIndex.value,
                            onSelected: (_) => state.repeaterIndex.value = i)),
                ])),
            IconButton(visualDensity: VisualDensity.compact, onPressed: _newTab, icon: const Icon(Icons.add)),
            IconButton(visualDensity: VisualDensity.compact, onPressed: _closeTab, icon: const Icon(Icons.close)),
          ])),
      Row(children: [
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton.icon(
                onPressed: sending ? null : _send,
                icon: sending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 16),
                label: const Text('Send'))),
        const SizedBox(width: 8),
        const Text('HTTPS', style: TextStyle(fontSize: 12)),
        Switch(value: tab?.https ?? true, onChanged: (v) => setState(() => tab?.https = v)),
      ]),
      const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Align(alignment: Alignment.centerLeft, child: Text('Request', style: TextStyle(fontSize: 11, color: Colors.grey)))),
      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(6, 2, 6, 4), child: RawEditor(controller: editor))),
      Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: Row(children: [
            Text('Response', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 8),
            if (tab?.status != null)
              Text('${tab!.status}', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor(tab.status))),
            if (tab?.length != null) Text('  ${tab!.length} bytes', style: const TextStyle(fontSize: 11)),
            if (tab?.millis != null) Text('  ${tab!.millis} ms', style: const TextStyle(fontSize: 11)),
            const Spacer(),
            if (tab?.responseRaw != null)
              IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.copy),
                  onPressed: () => copyText(context, tab!.responseRaw!)),
          ])),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: RawViewer(text: tab?.responseRaw ?? ''))),
    ]);
  }
}
