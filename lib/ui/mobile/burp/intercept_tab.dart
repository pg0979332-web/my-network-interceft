import 'package:flutter/material.dart';
import 'package:proxypin/network/components/intercept_queue.dart';
import 'package:proxypin/network/components/manager/request_breakpoint_manager.dart';
import 'package:proxypin/ui/mobile/burp/burp_state.dart';
import 'package:proxypin/ui/mobile/burp/burp_widgets.dart';

/// Burp "Proxy > Intercept": raw editor + Forward / Drop / Intercept on-off.
class InterceptTab extends StatefulWidget {
  const InterceptTab({super.key});

  @override
  State<InterceptTab> createState() => _InterceptTabState();
}

class _InterceptTabState extends State<InterceptTab> {
  final queue = InterceptQueue.instance;
  final state = BurpState.instance;
  final editor = TextEditingController();
  RequestBreakpointManager? manager;
  PendingIntercept? selected;

  @override
  void initState() {
    super.initState();
    RequestBreakpointManager.instance.then((m) {
      if (mounted) setState(() => manager = m);
    });
    queue.items.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    queue.items.removeListener(_onQueueChanged);
    editor.dispose();
    super.dispose();
  }

  void _onQueueChanged() {
    final list = queue.items.value;
    if (selected != null && !list.any((e) => identical(e, selected))) {
      selected = null;
      editor.text = '';
    }
    // Auto-select the first one like Burp does
    if (selected == null && list.isNotEmpty) {
      _select(list.first);
    }
    if (mounted) setState(() {});
  }

  void _select(PendingIntercept item) {
    selected = item;
    editor.text = item.isResponse ? BurpState.rawResponse(item.response!) : BurpState.rawRequest(item.request);
  }

  Future<void> _toggle(bool on) async {
    final m = manager;
    if (m == null) return;
    m.interceptAll = on;
    if (on) m.enabled = true;
    if (!on) {
      m.interceptAllResponse = false;
      await m.save();
      queue.releaseAll();
    } else {
      await m.save();
    }
    setState(() {});
  }

  Future<void> _toggleResponses(bool on) async {
    final m = manager;
    if (m == null) return;
    m.interceptAllResponse = on;
    if (on) m.enabled = true;
    await m.save();
    if (!on) {
      for (var e in queue.items.value.where((e) => e.isResponse).toList()) {
        queue.forward(e);
      }
    }
    setState(() {});
  }

  void _forward() {
    final item = selected;
    if (item == null) return;
    try {
      if (item.isResponse) {
        queue.forward(item, modifiedResponse: BurpState.parseResponse(editor.text));
      } else {
        final https = item.request.hostAndPort?.scheme == 'https://';
        queue.forward(item, modifiedRequest: BurpState.parseRequest(editor.text, https: https));
      }
    } catch (e) {
      toast(context, 'Cannot parse: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = manager;
    final on = m?.interceptAll == true;
    final item = selected;

    return Column(children: [
      Row(children: [
        Expanded(
            child: SwitchListTile(
                dense: true,
                title: Text(on ? 'Intercept is on' : 'Intercept is off',
                    style: TextStyle(fontWeight: FontWeight.w700, color: on ? Colors.red : null)),
                value: on,
                onChanged: m == null ? null : _toggle)),
        Row(children: [
          const Text('Resp', style: TextStyle(fontSize: 12)),
          Checkbox(
              value: m?.interceptAllResponse == true,
              onChanged: (m == null || !on) ? null : (v) => _toggleResponses(v == true)),
        ]),
      ]),
      Row(children: [
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton(
                onPressed: item == null ? null : _forward,
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Forward'))),
        const SizedBox(width: 6),
        Expanded(
            child: FilledButton(
                onPressed: item == null ? null : () => queue.drop(item),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Drop'))),
        PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'all':
                  queue.forwardAll();
                  break;
                case 'dropall':
                  queue.dropAll();
                  break;
                case 'repeater':
                  if (item != null) state.sendRequestToRepeater(item.request);
                  break;
                case 'intruder':
                  if (item != null) state.sendRequestToIntruder(item.request);
                  break;
              }
            },
            itemBuilder: (_) => const [
                  PopupMenuItem(value: 'all', child: Text('Forward all')),
                  PopupMenuItem(value: 'dropall', child: Text('Drop all')),
                  PopupMenuItem(value: 'repeater', child: Text('Send to Repeater')),
                  PopupMenuItem(value: 'intruder', child: Text('Send to Intruder')),
                ]),
      ]),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  item == null
                      ? (on ? 'Waiting for requests…' : 'Turn intercept on to hold requests')
                      : '${item.isResponse ? 'Response' : 'Request'} to ${item.request.hostAndPort?.host ?? ''}   '
                          '(${queue.items.value.length} queued)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)))),
      // queue chips
      SizedBox(
          height: 34,
          child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: queue.items.value
                  .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${e.isResponse ? 'RES' : e.request.method.name} ${e.request.hostAndPort?.host ?? ''}',
                              style: const TextStyle(fontSize: 11)),
                          selected: identical(e, selected),
                          onSelected: (_) => setState(() => _select(e)))))
                  .toList())),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.all(6),
              child: RawEditor(controller: editor, hint: 'Intercepted request appears here'))),
    ]);
  }
}
