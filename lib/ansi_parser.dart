import 'package:flutter/material.dart';

class AnsiParser {
  static List<TextSpan> parseAnsiString(String text) {
    List<TextSpan> spans = [];
    RegExp ansiRegex = RegExp(r'\x1b\[([\d;]*)m');
    String currentText = '';
    Color currentColor = Colors.green;

    void addSpan() {
      if (currentText.isNotEmpty) {
        spans.add(
            TextSpan(text: currentText, style: TextStyle(color: currentColor)));
        currentText = '';
      }
    }

    int currentIndex = 0;
    for (Match match in ansiRegex.allMatches(text)) {
      String beforeMatch = text.substring(currentIndex, match.start);
      currentText += beforeMatch;

      String code = match.group(1) ?? '';
      if (code == '0') {
        addSpan();
        currentColor = Colors.green;
      } else if (code.startsWith('38;5;')) {
        addSpan();
        int colorCode = int.parse(code.split(';').last);
        currentColor = _ansi256ToColor(colorCode);
      } else if (code.startsWith('38;2;')) {
        addSpan();
        var parts = code.split(';');
        int r = int.parse(parts[1]);
        int g = int.parse(parts[2]);
        int b = int.parse(parts[3]);
        currentColor = Color.fromARGB(255, r, g, b);
      }

      currentIndex = match.end;
    }

    currentText += text.substring(currentIndex);
    addSpan();

    return spans;
  }

  static Color _ansi256ToColor(int code) {
    if (code < 16) {
      return _basicAnsiColor(code);
    } else if (code < 232) {
      code -= 16;
      int r = (code / 36).floor() * 51;
      int g = ((code % 36) / 6).floor() * 51;
      int b = (code % 6) * 51;
      return Color.fromARGB(255, r, g, b);
    } else {
      int gray = (code - 232) * 10 + 8;
      return Color.fromARGB(255, gray, gray, gray);
    }
  }

  static Color _basicAnsiColor(int code) {
    switch (code) {
      case 0:
        return Colors.black;
      case 1:
        return Colors.red;
      case 2:
        return Colors.green;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.blue;
      case 5:
        return Colors.indigo;
      case 6:
        return Colors.cyan;
      case 7:
        return Colors.white;
      case 8:
        return Colors.grey;
      case 9:
        return Colors.red.shade700;
      case 10:
        return Colors.green.shade700;
      case 11:
        return Colors.yellow.shade700;
      case 12:
        return Colors.blue.shade700;
      case 13:
        return Colors.purple.shade700;
      case 14:
        return Colors.cyan.shade700;
      case 15:
        return Colors.white70;
      default:
        return Colors.black;
    }
  }
}
