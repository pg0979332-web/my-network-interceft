import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Monospace multi-line editor used for raw HTTP text.
class RawEditor extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final String? hint;

  const RawEditor({super.key, required this.controller, this.readOnly = false, this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      enableSuggestions: false,
      autocorrect: false,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
      decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.all(8),
          border: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).dividerColor))),
    );
  }
}

/// Read-only raw text viewer (selectable).
class RawViewer extends StatelessWidget {
  final String text;

  const RawViewer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5))),
    );
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(milliseconds: 800)));
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

Color statusColor(int? code) {
  if (code == null) return Colors.grey;
  if (code >= 500) return Colors.purple;
  if (code >= 400) return Colors.red;
  if (code >= 300) return Colors.orange;
  if (code >= 200) return Colors.green;
  return Colors.grey;
}
