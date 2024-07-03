import 'dart:async';

import 'package:code_scout_web_logger/code_scout_logger_controller.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class CodeScoutLogger extends StatefulWidget {
  const CodeScoutLogger({super.key});

  @override
  State<CodeScoutLogger> createState() => _CodeScoutLoggerState();
}

class _CodeScoutLoggerState extends State<CodeScoutLogger> {
  final CodeScoutLoggerController codeScoutLoggerController =
      CodeScoutLoggerController();

  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    codeScoutLoggerController.init(setState);
    codeScoutLoggerController.run();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: size.height,
            child: TerminalView(
              scrollController: scrollController,
              codeScoutLoggerController.terminal,
              controller: codeScoutLoggerController.terminalController,
              onKeyEvent: codeScoutLoggerController.portInput,
              simulateScroll: true,
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: MaterialButton(
              onPressed: () {
                codeScoutLoggerController.refresh();
              },
              color: Colors.red,
              textColor: Colors.white,
              child: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}
