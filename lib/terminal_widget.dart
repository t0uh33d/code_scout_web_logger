import 'package:code_scout_web_logger/ansi_parser.dart';
import 'package:flutter/material.dart';

class TerminalWidget extends StatefulWidget {
  final List<String> logs;
  final Function(String) onInput;

  const TerminalWidget({
    Key? key,
    required this.logs,
    required this.onInput,
  }) : super(key: key);

  @override
  _TerminalWidgetState createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  child: RichText(
                    text: TextSpan(
                      children: AnsiParser.parseAnsiString(widget.logs[index]),
                      style: const TextStyle(fontFamily: 'Courier'),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('> ',
                    style:
                        TextStyle(color: Colors.green, fontFamily: 'Courier')),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                        color: Colors.green, fontFamily: 'Courier'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      widget.onInput(value);
                      _inputController.clear();
                      _focusNode.requestFocus();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
