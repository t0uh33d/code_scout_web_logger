import 'package:flutter/material.dart';
import 'code_scout_logger_controller.dart';
import 'terminal_widget.dart';

class CodeScoutLogger extends StatefulWidget {
  const CodeScoutLogger({Key? key}) : super(key: key);

  @override
  State<CodeScoutLogger> createState() => _CodeScoutLoggerState();
}

class _CodeScoutLoggerState extends State<CodeScoutLogger> {
  final CodeScoutLoggerController codeScoutLoggerController =
      CodeScoutLoggerController();

  @override
  void initState() {
    super.initState();
    codeScoutLoggerController.init(setState);
    codeScoutLoggerController.getConnectionDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CodeScout Logger v1'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: codeScoutLoggerController.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: TerminalWidget(
              logs: codeScoutLoggerController.logs,
              onInput: codeScoutLoggerController.handleInput,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              'State: ${codeScoutLoggerController.currentState.toString().split('.').last}'),
          Text('Port: ${codeScoutLoggerController.portNumber}'),
          Text(
              'Connected Clients: ${codeScoutLoggerController.socketMap.length}'),
        ],
      ),
    );
  }
}
