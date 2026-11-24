import 'package:flutter/material.dart';
import 'package:proxypin/ui/mobile/burp/burp_state.dart';

/// Burp "Target > Scope"-style host list + intercept filter settings.
class ScopeTab extends StatefulWidget {
  const ScopeTab({super.key});

  @override
  State<ScopeTab> createState() => _ScopeTabState();
}

class _ScopeTabState extends State<ScopeTab> {
  final state = BurpState.instance;
  final input = TextEditingController();

  void _add() {
    final v = input.text.trim();
    if (v.isEmpty) return;
    state.scope.value = [...state.scope.value, v];
    input.clear();
    setState(() {});
  }

  void _remove(String v) {
    state.scope.value = state.scope.value.where((e) => e != v).toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('Scope', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Add a domain (e.g. example.com) to limit History / Intercept to it. Empty = everything.',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: TextField(
                controller: input,
                decoration: const InputDecoration(isDense: true, hintText: 'example.com', border: OutlineInputBorder()),
                onSubmitted: (_) => _add())),
        const SizedBox(width: 8),
        FilledButton(onPressed: _add, child: const Text('Add')),
      ]),
      const SizedBox(height: 8),
      Wrap(
          spacing: 6,
          runSpacing: 6,
          children: state.scope.value.map((e) => Chip(label: Text(e), onDeleted: () => _remove(e))).toList()),
      const Divider(height: 28),
      const Text('Intercept filters', style: TextStyle(fontWeight: FontWeight.bold)),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Only intercept in-scope hosts'),
          value: state.interceptScopeOnly,
          onChanged: (v) => setState(() => state.interceptScopeOnly = v)),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Skip static files (images, css, js, fonts)'),
          subtitle: const Text('Recommended — stops intercept from pausing on every image'),
          value: state.skipStaticFiles,
          onChanged: (v) => setState(() => state.skipStaticFiles = v)),
    ]);
  }
}
