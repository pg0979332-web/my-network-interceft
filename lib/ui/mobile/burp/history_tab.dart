import 'package:flutter/material.dart';
import 'package:proxypin/ui/mobile/burp/burp_state.dart';
import 'package:proxypin/ui/mobile/burp/burp_widgets.dart';

/// Burp "Proxy > HTTP history".
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final state = BurpState.instance;
  String query = '';
  bool scopeOnly = false;
  String method = 'ALL';

  @override
  void initState() {
    super.initState();
    scopeOnly = state.historyScopeOnly;
  }

  bool _match(BurpItem i) {
    if (scopeOnly && !state.inScope(i.host)) return false;
    if (method != 'ALL' && i.request.method.name != method) return false;
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return i.request.requestUrl.toLowerCase().contains(q) ||
        '${i.status ?? ''}'.contains(q) ||
        BurpState.bodyText(i.request).toLowerCase().contains(q) ||
        (i.response != null && BurpState.bodyText(i.response!).toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(children: [
            Expanded(
                child: TextField(
                    decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                        hintText: 'Filter: url / status / body text',
                        border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => query = v))),
            const SizedBox(width: 6),
            DropdownButton<String>(
                value: method,
                underline: const SizedBox(),
                items: ['ALL', 'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS', 'HEAD']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) => setState(() => method = v ?? 'ALL')),
            IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => showDialog(
                    context: context,
                    builder: (c) => AlertDialog(title: const Text('Clear history?'), actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('No')),
                          TextButton(
                              onPressed: () {
                                state.clearHistory();
                                Navigator.pop(c);
                              },
                              child: const Text('Clear')),
                        ]))),
          ])),
      CheckboxListTile(
          dense: true,
          title: const Text('Only in-scope hosts', style: TextStyle(fontSize: 13)),
          value: scopeOnly,
          onChanged: (v) => setState(() {
                scopeOnly = v == true;
                state.historyScopeOnly = scopeOnly;
              })),
      const Divider(height: 0),
      Expanded(
          child: ValueListenableBuilder<List<BurpItem>>(
              valueListenable: state.history,
              builder: (context, all, _) {
                final list = all.where(_match).toList().reversed.toList();
                if (list.isEmpty) return const Center(child: Text('No requests', style: TextStyle(color: Colors.grey)));
                return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final it = list[i];
                      final uri = it.request.requestUri;
                      final path = uri == null ? it.request.uri : '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => HistoryDetailPage(item: it))),
                        leading: SizedBox(
                            width: 44,
                            child: Text('${it.no}\n${it.request.method.name}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                        title: Text(it.host, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${it.status ?? '-'}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor(it.status))),
                          Text('${it.length}b', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      );
                    });
              })),
    ]);
  }
}

class HistoryDetailPage extends StatelessWidget {
  final BurpItem item;

  const HistoryDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final req = BurpState.rawRequest(item.request);
    final res = item.response == null ? '(no response yet)' : BurpState.rawResponse(item.response!);
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
              title: Text('#${item.no} ${item.request.method.name}', style: const TextStyle(fontSize: 15)),
              bottom: const TabBar(tabs: [Tab(text: 'Request'), Tab(text: 'Response')]),
              actions: [
                PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'repeater') {
                        BurpState.instance.sendToRepeater(item);
                        Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == 'burp');
                      } else if (v == 'intruder') {
                        BurpState.instance.sendRequestToIntruder(item.request);
                        Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == 'burp');
                      } else if (v == 'copyreq') {
                        copyText(context, req);
                      } else if (v == 'copyres') {
                        copyText(context, res);
                      } else if (v == 'curl') {
                        copyText(context, _curl(item));
                      }
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(value: 'repeater', child: Text('Send to Repeater')),
                          PopupMenuItem(value: 'intruder', child: Text('Send to Intruder')),
                          PopupMenuItem(value: 'curl', child: Text('Copy as cURL')),
                          PopupMenuItem(value: 'copyreq', child: Text('Copy request')),
                          PopupMenuItem(value: 'copyres', child: Text('Copy response')),
                        ])
              ]),
          body: TabBarView(children: [
            Padding(padding: const EdgeInsets.all(6), child: RawViewer(text: req)),
            Padding(padding: const EdgeInsets.all(6), child: RawViewer(text: res)),
          ]),
        ));
  }

  static String _curl(BurpItem it) {
    final r = it.request;
    final sb = StringBuffer("curl -i -k -X ${r.method.name} '${r.requestUrl}'");
    r.headers.forEach((name, values) {
      final n = name.toLowerCase();
      if (n == 'content-length' || n == 'host') return;
      for (var v in values) {
        sb.write(" -H '$name: ${v.replaceAll("'", "'\\''")}'");
      }
    });
    final body = BurpState.bodyText(r);
    if (body.isNotEmpty) sb.write(" --data-binary '${body.replaceAll("'", "'\\''")}'");
    return sb.toString();
  }
}
