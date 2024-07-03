import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cw_core/cw_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum CodeScoutLoggerState {
  initializing,
  portInput,
  ready,
  waitingForConnection,
  connecting,
  connected,
}

typedef StateUpdater = void Function(void Function() fn);

class CodeScoutLoggerController extends ChangeNotifier {
  List<String> logs = [];
  late StateUpdater _stateUpdater;

  CodeScoutLoggerState currentState = CodeScoutLoggerState.initializing;
  int portNumber = 0;
  String ipAddress = '';
  String identifier = '';

  Map<String, bool> connectionInitiators = {};
  Map<String, Socket> socketMap = {};
  Socket? establishedConnection;
  ServerSocket? server;

  void init(StateUpdater stateUpdater) {
    _stateUpdater = stateUpdater;
  }

  void refresh() {
    server?.close();
    logs.clear();
    currentState = CodeScoutLoggerState.initializing;
    portNumber = 0;
    ipAddress = '';
    identifier = '';
    connectionInitiators.clear();
    socketMap.clear();
    establishedConnection = null;
    _stateUpdater.call(() {});
    getConnectionDetails();
  }

  void terminalWrite(String data, {Color color = Colors.green}) {
    String colorCode = '';
    if (color != Colors.green) {
      int r = color.red;
      int g = color.green;
      int b = color.blue;
      colorCode = '\x1b[38;2;$r;$g;${b}m';
    }
    logs.add('$colorCode$data\x1b[0m');
    _stateUpdater.call(() {});
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
    terminalWrite('Enter a port number (1-65535): ');
    currentState = CodeScoutLoggerState.portInput;
    notifyListeners();
  }

  void handleInput(String input) {
    if (currentState == CodeScoutLoggerState.portInput) {
      int? port = int.tryParse(input);
      if (port != null && port > 0 && port <= 65535) {
        portNumber = port;
        run();
      } else {
        terminalWrite(
            'Invalid port number. Please enter a number between 1 and 65535.');
      }
    }
  }

  Future<void> run() async {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    String localIP = interfaces.first.addresses.first.address;
    server = await ServerSocket.bind(localIP, portNumber);
    identifier = generateIdentifier();

    ipAddress = localIP;
    terminalWrite('IP Address : $ipAddress', color: Colors.yellow);
    terminalWrite('Port : $portNumber', color: Colors.yellow);
    terminalWrite('Identifier : $identifier', color: Colors.yellow);

    _stateUpdater(() {
      currentState = CodeScoutLoggerState.ready;
    });

    await for (Socket socket in server!) {
      _handleIncomingConnection(socket);
    }
  }

  void _handleIncomingConnection(Socket socket) {
    socket.listen(
      (List<int> event) async {
        String data = utf8.decode(event);
        _handleIncomingData(socket, data);
      },
      onError: (error) {
        terminalWrite("Error: $error");
      },
      onDone: () {
        terminalWrite("Connection closed");
        socket.close();
      },
      cancelOnError: true,
    );
  }

  void _handleIncomingData(Socket socket, String data) {
    try {
      CodeScoutComms codeScoutComms = CodeScoutComms.fromJson(data);
      if (codeScoutComms.command == CodeScoutCommands.communication) {
        String output =
            utf8.decode(List<int>.from(codeScoutComms.data['output']));
        terminalWrite(output);
      } else if (codeScoutComms.command ==
          CodeScoutCommands.establishConnection) {
        _establishConnection(socket, codeScoutComms);
      }
    } catch (e) {
      terminalWrite("Error processing incoming data: $e");
    }
  }

  void _establishConnection(Socket socket, CodeScoutComms comms) {
    String ipStr = socket.remoteAddress.address;
    terminalWrite('Connection request from $ipStr');

    if (establishedConnection != null) {
      _rejectConnection(socket, ipStr);
      return;
    }

    _authenticate(comms, ipStr, socket);
  }

  void _authenticate(CodeScoutComms comms, String ipStr, Socket socket) async {
    if (establishedConnection != null) {
      _rejectConnection(socket, ipStr);
      return;
    }

    if (comms.data[CodeScoutPayloadType.identifier] == identifier) {
      connectionInitiators[ipStr] = true;
      establishedConnection = socket;
      terminalWrite("Connection established!!");
      currentState = CodeScoutLoggerState.connected;
      notifyListeners();

      socket.write(
        CodeScoutComms(
          command: CodeScoutCommands.connectionApproved,
          payloadType: CodeScoutPayloadType.identifier,
          data: {},
        ).toJson(),
      );

      _notifyOtherSockets();
    } else {
      terminalWrite("Invalid identifier from $ipStr");
      socket.write(
        CodeScoutComms(
          command: CodeScoutCommands.breakConnection,
          payloadType: CodeScoutPayloadType.identifier,
          data: {},
        ).toJson(),
      );
      await socket.flush();
      await socket.close();
    }
  }

  void _rejectConnection(Socket socket, String ipStr) {
    if (connectionInitiators.containsKey(ipStr) &&
        connectionInitiators[ipStr]!) {
      return;
    }

    terminalWrite(
        'Refused connection from $ipStr, already connected to another client');
    socket.write('Only one connection allowed at a time!');
    socket.close();
  }

  void _notifyOtherSockets() {
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
