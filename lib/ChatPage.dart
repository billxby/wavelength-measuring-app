import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class ChartData{
  ChartData(this.x, this.y);
  final int x;
  final double? y;
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;
  bool lightIsActive = false;
  String fullOutputRead = "";
  bool readingFullOutput = false;
  List<double> wavelengths = [0, 0, 0, 0, 0, 0];
  List<int> channels = [450, 500, 550, 570, 600, 650];
  List<String> channelsText = ["V", "B", "G", "Y", "O", "R"];
  List<ChartData> chartData = [];

  void interpretString() {
    print(fullOutputRead);

    fullOutputRead = fullOutputRead.substring(1, fullOutputRead.length-1);

    for (int i=0;i<5;i++) {
      wavelengths[i] = double.tryParse(fullOutputRead.substring(0, fullOutputRead.indexOf(";")))!;
      fullOutputRead = fullOutputRead.substring(fullOutputRead.indexOf(";")+1, fullOutputRead.length);
    }
    wavelengths[5] = double.tryParse(fullOutputRead)!;

    chartData.clear();

    for (int i=0;i<6;i++) {
      chartData.add(
        ChartData(channels[i], wavelengths[i])
      );
    }

    fullOutputRead = "";
  }

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final List<Row> list = messages.map((_message) {
    //   return Row(
    //     mainAxisAlignment: _message.whom == clientID
    //         ? MainAxisAlignment.end
    //         : MainAxisAlignment.start,
    //     children: <Widget>[
    //       Container(
    //         padding: EdgeInsets.all(12.0),
    //         margin: EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
    //         width: 222.0,
    //         decoration: BoxDecoration(
    //             color:
    //                 _message.whom == clientID ? Colors.blueAccent : Colors.grey,
    //             borderRadius: BorderRadius.circular(7.0)),
    //         child: Text(
    //             (text) {
    //               return text == '/shrug' ? '¯\\_(ツ)_/¯' : text;
    //             }(_message.text.trim()),
    //             style: TextStyle(color: Colors.white)),
    //       ),
    //     ],
    //   );
    // }).toList();

    final serverName = widget.server.name ?? "Unknown";
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connection à ' + serverName + '...')
              : isConnected
                  ? Text(serverName)
                  : Text(serverName))),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // Flexible(
            //   child: ListView(
            //       padding: const EdgeInsets.all(12.0),
            //       controller: listScrollController,
            //       children: list),
            // ),
            Divider(),
            ListTile(title: const Text('Contrôle', style: TextStyle(fontWeight: FontWeight.bold))),
            SwitchListTile(
              title: const Text('Lumière'),
              value: lightIsActive,
              onChanged: (bool value) {

                _sendMessage(!value ? "B" : "A");
                lightIsActive = value;

                setState(() {});
              },
            ),

            Divider(),

            ListTile(title: const Text('Mesure', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(channelsText.toString()),),
            Text(wavelengths.toString()),

            SizedBox(height: 20),

            ListTile(
              title: const Text('Relire la couleur'),
              subtitle: Text("Assurez vous qu'il n'y a pas de poussieres"),
              trailing: ElevatedButton(
                child: const Text('Mesurer'),
                onPressed: () {
                  _sendMessage("C");
                },
              ),
            ),

            SizedBox(height: 10),

            Divider(),

            ListTile(title: const Text('Analyse', style: TextStyle(fontWeight: FontWeight.bold))),

            SizedBox(height: 20),

            SizedBox(
              height: 400,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                    title: AxisTitle(
                      text: 'Chaîne (μW/cm2)',
                    )
                ),
                series: <ChartSeries>[
                  SplineSeries<ChartData, int>(
                      dataSource: chartData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y
                  )
                ],
              ),
            ),

            SizedBox(height: 10),

            ListTile(
              title: const Text('Couleur'),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  child: Text('#FFFFFF 📄', style: TextStyle(color: Colors.black)),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: "#FFFFFF"));
                  },
                ),
              ),
              trailing: Container(height: 30, width: 30, color: Colors.redAccent),
            ),

            Divider(),

            ListTile(title: const Text('Commandes Chat', style: TextStyle(fontWeight: FontWeight.bold))),

            SizedBox(height: 20),

            Row(
              children: <Widget>[
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16.0),
                    child: TextField(
                      style: const TextStyle(fontSize: 15.0),
                      controller: textEditingController,
                      decoration: InputDecoration.collapsed(
                        hintText: isConnecting
                            ? 'Wait until connected...'
                            : isConnected
                            ? 'Type your message...'
                            : 'Chat got disconnected',
                        hintStyle: const TextStyle(color: Colors.grey),
                      ),
                      enabled: isConnected,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8.0),
                  child: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: isConnected
                          ? () => _sendMessage(textEditingController.text)
                          : null),
                ),
              ],
            )
          ],
        ),
      )
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);

    // print(dataString);

    if (dataString.contains("R")) {
      fullOutputRead+="R";
      readingFullOutput = true;
    }
    else if (readingFullOutput) {
      fullOutputRead += dataString;
      if (dataString.contains("T")) {
        readingFullOutput = false;
        interpretString();

        setState(() {
        });
      }
    }

    // int index = buffer.indexOf(13);
    // if (~index != 0) {
    //   setState(() {
    //     messages.add(
    //       _Message(
    //         1,
    //         backspacesCounter > 0
    //             ? _messageBuffer.substring(
    //                 0, _messageBuffer.length - backspacesCounter)
    //             : _messageBuffer + dataString.substring(0, index),
    //       ),
    //     );
    //     _messageBuffer = dataString.substring(index);
    //   });
    // } else {
    //   _messageBuffer = (backspacesCounter > 0
    //       ? _messageBuffer.substring(
    //           0, _messageBuffer.length - backspacesCounter)
    //       : _messageBuffer + dataString);
    // }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;

        setState(() {

        });

        // setState(() {
        //   messages.add(_Message(clientID, text));
        // });
        //
        // Future.delayed(Duration(milliseconds: 333)).then((_) {
        //   listScrollController.animateTo(
        //       listScrollController.position.maxScrollExtent,
        //       duration: Duration(milliseconds: 333),
        //       curve: Curves.easeOut);
        // });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
