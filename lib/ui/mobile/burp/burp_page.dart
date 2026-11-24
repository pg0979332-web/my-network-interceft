import 'package:flutter/material.dart';
import 'package:proxypin/network/components/intercept_queue.dart';
import 'package:proxypin/ui/mobile/burp/burp_state.dart';
import 'package:proxypin/ui/mobile/burp/decoder_tab.dart';
import 'package:proxypin/ui/mobile/burp/history_tab.dart';
import 'package:proxypin/ui/mobile/burp/intercept_tab.dart';
import 'package:proxypin/ui/mobile/burp/intruder_tab.dart';
import 'package:proxypin/ui/mobile/burp/repeater_tab.dart' as repeater;
import 'package:proxypin/ui/mobile/burp/scope_tab.dart';

/// Burp-style top-level page: Intercept / History / Repeater / Intruder / Decoder / Scope.
class BurpPage extends StatefulWidget {
  const BurpPage({super.key});

  @override
  State<BurpPage> createState() => _BurpPageState();
}

class _BurpPageState extends State<BurpPage> with SingleTickerProviderStateMixin {
  late final TabController controller;
  final state = BurpState.instance;

  static const _titles = ['Intercept', 'History', 'Repeater', 'Intruder', 'Decoder', 'Scope'];

  @override
  void initState() {
    super.initState();
    controller = TabController(length: _titles.length, vsync: this);
    state.requestedTab.addListener(_onRequestedTab);
  }

  @override
  void dispose() {
    state.requestedTab.removeListener(_onRequestedTab);
    controller.dispose();
    super.dispose();
  }

  void _onRequestedTab() {
    final i = state.requestedTab.value;
    if (i >= 0 && i < _titles.length) controller.animateTo(i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy Intercept', style: TextStyle(fontSize: 16)),
        centerTitle: true,
        bottom: TabBar(
            controller: controller,
            isScrollable: true,
            tabs: [
              for (var i = 0; i < _titles.length; i++)
                Tab(
                    child: i == 0
                        ? ValueListenableBuilder<List<PendingIntercept>>(
                            valueListenable: InterceptQueue.instance.items,
                            builder: (_, list, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_titles[i]),
                                  if (list.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    CircleAvatar(
                                        radius: 8,
                                        backgroundColor: Colors.red,
                                        child: Text('${list.length}', style: const TextStyle(fontSize: 10, color: Colors.white))),
                                  ]
                                ]))
                        : Text(_titles[i]))
            ]),
      ),
      body: TabBarView(controller: controller, children: const [
        InterceptTab(),
        HistoryTab(),
        repeater.RepeaterTab(),
        IntruderTab(),
        DecoderTab(),
        ScopeTab(),
      ]),
    );
  }
}
