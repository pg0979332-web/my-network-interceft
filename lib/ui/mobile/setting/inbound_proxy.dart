import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proxypin/network/bin/configuration.dart';
import 'package:proxypin/utils/ip.dart';

/// Proxy credentials for clients that connect TO this app (other devices / SIM APN etc).
/// This phone's own VPN capture (loopback) never needs them.
class InboundProxyDialog extends StatefulWidget {
  final Configuration configuration;

  const InboundProxyDialog({super.key, required this.configuration});

  @override
  State<InboundProxyDialog> createState() => _InboundProxyDialogState();
}

class _InboundProxyDialogState extends State<InboundProxyDialog> {
  late TextEditingController user;
  late TextEditingController pass;
  late TextEditingController port;
  List<String> ips = [];

  @override
  void initState() {
    super.initState();
    user = TextEditingController(text: widget.configuration.proxyUsername ?? '');
    pass = TextEditingController(text: widget.configuration.proxyPassword ?? '');
    port = TextEditingController(text: widget.configuration.port.toString());
    localIps().then((v) {
      if (mounted) setState(() => ips = v.where((e) => !e.startsWith('127.')).toList());
    });
  }

  String _rand(int n) {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final ip = ips.isNotEmpty ? ips.first : '<phone-ip>';
    final cfg = widget.configuration;
    return AlertDialog(
      scrollable: true,
      title: const Text('Proxy Generator (IP:Port:User:Pass)', style: TextStyle(fontSize: 15)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: port,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            decoration: const InputDecoration(labelText: 'Port')),
        TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')),
        TextField(controller: pass, decoration: const InputDecoration(labelText: 'Password')),
        const SizedBox(height: 8),
        Row(children: [
          TextButton(
              onPressed: () => setState(() {
                    user.text = 'u${_rand(5)}';
                    pass.text = _rand(10);
                  }),
              child: const Text('Generate')),
          TextButton(
              onPressed: () => setState(() {
                    user.clear();
                    pass.clear();
                  }),
              child: const Text('No auth')),
        ]),
        const SizedBox(height: 8),
        SelectableText('$ip:${port.text}${user.text.isNotEmpty ? ':${user.text}:${pass.text}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(
                text: '$ip:${port.text}${user.text.isNotEmpty ? ':${user.text}:${pass.text}' : ''}')),
            child: const Text('Copy')),
        const SizedBox(height: 6),
        const Text(
            'Credentials apply to outside clients only. Traffic captured by this phone\'s own VPN never needs them. '
            'Restart capture after changing the port.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
            onPressed: () {
              cfg.proxyUsername = user.text.trim().isEmpty ? null : user.text.trim();
              cfg.proxyPassword = pass.text.isEmpty ? null : pass.text;
              final p = int.tryParse(port.text);
              if (p != null && p > 0 && p < 65536) cfg.port = p;
              cfg.flushConfig();
              Navigator.of(context).pop();
            },
            child: const Text('Save')),
      ],
    );
  }
}
