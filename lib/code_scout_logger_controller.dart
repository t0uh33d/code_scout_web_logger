import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cw_core/cw_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

enum CodeScoutLoggerState {
  initalizing,
  portInput,
  ready,
  waitingForConnection,
  connecting,
  connected,
}

typedef StateUpdater = void Function(void Function() fn);

class CodeScoutLoggerController extends ChangeNotifier {
  Map<String, bool> connectionInitiators = {};
  Map<String, Socket> socketMap = {};
  Socket? establishedConnection;

  final Terminal terminal = Terminal();
  final TerminalController terminalController = TerminalController();

  late StateUpdater _stateUpdater;
  late ServerSocket server;

  CodeScoutLoggerState currentState = CodeScoutLoggerState.initalizing;

  void init(StateUpdater stateUpdater) {
    _stateUpdater = stateUpdater;
  }

  void refresh() {
    server.close();
    terminal.eraseDisplay();
    terminal.setCursor(0, 0);

    run();
  }

  void terminalWrite(String data) {
    terminal.write(data);
    terminal.cursorNextLine(1);
    terminal.scrollUp(1);
  }

  Future<void> getConnectionDetails() async {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    for (final NetworkInterface interface in interfaces) {
      terminalWrite('Interface: ${interface.name}');
      for (final InternetAddress addr in interface.addresses) {
        terminalWrite('Address: ${addr.address}');
      }
    }
    terminal.cursorNextLine(1);

    terminalWrite('Enter a port number (1-65535): ');

    currentState = CodeScoutLoggerState.portInput;
  }

  int portNumber = 0;

  KeyEventResult portInput(FocusNode focusNode, KeyEvent keyEvent) {
    if (currentState != CodeScoutLoggerState.portInput) {
      return KeyEventResult.ignored;
    }

    if (keyEvent is KeyDownEvent &&
        keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
      // Handle Backspace key press (you can add your own logic here)

      portNumber = 0;

      return KeyEventResult.handled;
    }

    if (keyEvent is KeyDownEvent &&
        keyEvent.logicalKey == LogicalKeyboardKey.enter) {
      if (portNumber > 0 && portNumber <= 65535) {}
      return KeyEventResult.handled;
    }

    String? char = keyEvent.character;
    if (char == null) return KeyEventResult.ignored;

    int? num = int.tryParse(char);

    if (num == null) return KeyEventResult.ignored;

    int tmp = (portNumber * 10) + num;

    if (tmp > 65535) {
      return KeyEventResult.ignored;
    }

    portNumber = tmp;

    terminalWrite(char);

    return KeyEventResult.handled;
  }

  Future<void> run() async {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    for (final NetworkInterface interface in interfaces) {
      terminalWrite('Interface: ${interface.name}');
      for (final InternetAddress addr in interface.addresses) {
        terminalWrite('Address: ${addr.address}');
      }
    }
    terminalWrite('Enter a port number : ');

    // String? portStr = stdin.readLineSync();
    // int? port = int.tryParse(portStr ?? "");
    int port = 3939;

    if (port == null || port > 65535) {
      terminalWrite("Invalid Port specified.");
      exit(2);
    }

    String localIP = interfaces.first.addresses.first.address;
    server = await ServerSocket.bind(localIP, port);

    String id = generateIdentifier();

    terminalWrite('IP Address : $localIP');
    terminalWrite('Port : $port');
    terminalWrite('Identifier : $id');

    await for (Socket socket in server) {
      socket.listen(
        (Uint8List event) async {
          String data = String.fromCharCodes(event);

          CodeScoutComms codeScoutComms;
          try {
            codeScoutComms = CodeScoutComms.fromJson(data);
            print(codeScoutComms);
          } catch (e) {
            if (e is FormatException) {
              terminalWrite(
                "Format Execption : Data wasn't received properly from the app",
              );
              return;
            }
            terminalWrite('Invalid Comms, please follow the protocol.');

            exit(2);
          }
          if (codeScoutComms.command == CodeScoutCommands.communication) {
            String output = utf8.decode(
              List<int>.from(codeScoutComms.data['output']),
              allowMalformed: true,
            );
            output.split('\n').forEach(terminalWrite);
            return;
          }

          if (codeScoutComms.command == CodeScoutCommands.establishConnection) {
            _establishConnection(socket, codeScoutComms, id);
            return;
          }
        },
        onError: (error) {
          terminalWrite("Error: $error");
        },
        onDone: () {
          terminalWrite("Closing connection");
          server.close();
          exit(0);
        },
        cancelOnError: true,
      );
    }
  }

  void _establishConnection(Socket socket, CodeScoutComms comms, String id) {
    String ipStr = socket.remoteAddress.address;
    terminalWrite('Connection request from $ipStr');

    if (establishedConnection != null) {
      rejectConnection(socket, ipStr);
      return;
    }

    _authenticate(comms, id, ipStr, socket);
  }

  void _authenticate(
      CodeScoutComms comms, String id, String ipStr, Socket socket) async {
    if (establishedConnection != null) {
      rejectConnection(socket, ipStr);
      return;
    }

    if (comms.data[CodeScoutPayloadType.identifier] == id) {
      connectionInitiators[ipStr] = true;
      establishedConnection = socket;
      terminalWrite("Connection established!!");

      socket.write(
        CodeScoutComms(
          command: CodeScoutCommands.connectionApproved,
          payloadType: CodeScoutPayloadType.identifier,
          data: {},
        ),
      );

      notifyOtherSockets();
    } else {
      terminalWrite("Invalid identifier from $ipStr");
      socket.write(
        CodeScoutComms(
          command: CodeScoutCommands.breakConnection,
          payloadType: CodeScoutPayloadType.identifier,
          data: {},
        ),
      );
      await socket.flush();
      await socket.close();
    }
  }

  void rejectConnection(Socket socket, String ipStr) {
    if (connectionInitiators.containsKey(ipStr) &&
        connectionInitiators[ipStr]!) {
      return;
    }

    terminalWrite(
        'Refused connection from $ipStr, already connected to another client');
    socket.write('Only one connection allowed at a time!');
    socket.close();
  }

  void notifyOtherSockets() {
    socketMap.forEach((key, value) {
      if (!connectionInitiators[key]!) {
        value.write('Only one connection allowed at a time!');
        value.close();
      }
    });
  }

  String generateIdentifier() {
    final random = math.Random();
    return List.generate(5, (_) => random.nextInt(10).toString()).join('');
  }
}
