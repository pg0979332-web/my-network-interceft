import 'package:flutter/material.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/components/intercept_queue.dart';
import 'package:proxypin/network/components/manager/request_breakpoint_manager.dart';
import 'package:proxypin/ui/mobile/request/request_editor.dart';
import 'package:proxypin/ui/mobile/request/request_editor_source.dart';

/// Burp-style Intercept screen.
/// ON  => every request is held in the list below until you press Forward (or Drop).
/// OFF => everything flows normally and anything still held is released.
class InterceptPage extends StatefulWidget {
  const InterceptPage({super.key});

  @override
  State<InterceptPage> createState() => _InterceptPageState();
}

class _InterceptPageState extends State<InterceptPage> {
  RequestBreakpointManager? manager;
  final queue = InterceptQueue.instance;

  @override
  void initState() {
    super.initState();
    RequestBreakpointManager.instance.then((m) {
      if (mounted) setState(() => manager = m);
    });
  }

  Future<void> _setIntercept(bool on) async {
    final m = manager!;
    m.interceptAll = on;
    if (on) m.enabled = true;
    if (!on) {
      m.interceptAllResponse = false;
    }
    await m.save();
    if (!on) queue.releaseAll();
    setState(() {});
  }

  Future<void> _setResponses(bool on) async {
    final m = manager!;
    m.interceptAllResponse = on;
    if (on) {
      m.enabled = true;
    } else {
      for (var e in queue.items.value.where((e) => e.isResponse).toList()) {
        queue.forward(e);
      }
    }
    await m.save();
    setState(() {});
  }

  void _open(PendingIntercept item) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MobileRequestEditor(
              request: item.request,
              response: item.response,
              proxyServer: ProxyServer.current,
              source: item.isResponse ? RequestEditorSource.breakpointResponse : RequestEditorSource.breakpointRequest,
              // Editor calls back with null when you leave without pressing Forward: keep it queued.
              onExecuteRequest: (newRequest) {
                if (newRequest == null) return;
                queue.forward(item, modifiedRequest: newRequest);
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              onExecuteResponse: (newResponse) {
                if (newResponse == null) return;
                queue.forward(item, modifiedResponse: newResponse);
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            )));
  }

  @override
  Widget build(BuildContext context) {
    final m = manager;
    final on = m?.interceptAll == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Intercept', style: TextStyle(fontSize: 16)), centerTitle: true, actions: [
        TextButton(onPressed: queue.forwardAll, child: const Text('Forward all')),
        TextButton(onPressed: queue.dropAll, child: const Text('Drop all')),
      ]),
      body: Column(children: [
        SwitchListTile(
            title: Text(on ? 'Intercept is ON' : 'Intercept is OFF',
                style: TextStyle(fontWeight: FontWeight.w600, color: on ? Colors.red : null)),
            subtitle: const Text('ON: all GET/POST/etc are held until you Forward. OFF: normal traffic.'),
            value: on,
            onChanged: m == null ? null : _setIntercept),
        CheckboxListTile(
            dense: true,
            title: const Text('Also intercept responses'),
            value: m?.interceptAllResponse == true,
            onChanged: (m == null || !on) ? null : (v) => _setResponses(v == true)),
        const Divider(height: 0),
        Expanded(
            child: ValueListenableBuilder<List<PendingIntercept>>(
                valueListenable: queue.items,
                builder: (context, list, _) {
                  if (list.isEmpty) {
                    return Center(
                        child: Text(on ? 'Waiting for requests…' : 'Turn Intercept ON to hold requests',
                            style: const TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, i) {
                        final item = list[i];
                        final r = item.request;
                        final host = r.hostAndPort?.host ?? '';
                        return ListTile(
                          dense: true,
                          onTap: () => _open(item),
                          leading: Text(item.isResponse ? 'RES' : r.method.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.isResponse ? Colors.orange : Theme.of(context).colorScheme.primary)),
                          title: Text('$host${r.path}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.requestUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                tooltip: 'Forward',
                                icon: const Icon(Icons.play_arrow, color: Colors.green),
                                onPressed: () => queue.forward(item)),
                            IconButton(
                                tooltip: 'Drop',
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => queue.drop(item)),
                          ]),
                        );
                      });
                })),
      ]),
    );
  }
}
