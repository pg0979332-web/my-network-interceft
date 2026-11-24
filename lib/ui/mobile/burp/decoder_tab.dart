import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:proxypin/ui/mobile/burp/burp_widgets.dart';

/// Burp Decoder: encode/decode text with common schemes.
class DecoderTab extends StatefulWidget {
  const DecoderTab({super.key});

  @override
  State<DecoderTab> createState() => _DecoderTabState();
}

class _DecoderTabState extends State<DecoderTab> {
  final input = TextEditingController();
  final output = TextEditingController();
  String mode = 'URL';
  bool decode = true;

  void _run() {
    final text = input.text;
    try {
      String result;
      switch (mode) {
        case 'URL':
          result = decode ? Uri.decodeComponent(text) : Uri.encodeComponent(text);
          break;
        case 'Base64':
          result = decode ? utf8.decode(base64.decode(_pad(text)), allowMalformed: true) : base64.encode(utf8.encode(text));
          break;
        case 'Hex':
          result = decode ? _fromHex(text) : _toHex(text);
          break;
        case 'HTML':
          result = decode ? _htmlDecode(text) : _htmlEncode(text);
          break;
        default:
          result = text;
      }
      output.text = result;
    } catch (e) {
      output.text = 'Error: $e';
    }
  }

  String _pad(String s) {
    final t = s.trim();
    return t + '=' * ((4 - t.length % 4) % 4);
  }

  String _toHex(String s) => utf8.encode(s).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  String _fromHex(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i + 1 < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _htmlEncode(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');

  String _htmlDecode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            DropdownButton<String>(
                value: mode,
                items: ['URL', 'Base64', 'Hex', 'HTML'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => mode = v ?? mode)),
            const SizedBox(width: 10),
            ChoiceChip(label: const Text('Decode'), selected: decode, onSelected: (_) => setState(() => decode = true)),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text('Encode'), selected: !decode, onSelected: (_) => setState(() => decode = false)),
            const Spacer(),
            FilledButton(onPressed: _run, child: const Text('Run')),
          ])),
      const Padding(
          padding: EdgeInsets.only(left: 10, top: 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('Input', style: TextStyle(fontSize: 11, color: Colors.grey)))),
      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(8, 2, 8, 4), child: RawEditor(controller: input))),
      Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: Row(children: [
            const Text('Output', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.copy),
                onPressed: () => copyText(context, output.text)),
          ])),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: RawEditor(controller: output, readOnly: true))),
    ]);
  }
}
