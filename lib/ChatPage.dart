import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scidart/numdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

int maxDeg = 3;

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
  final double x;
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
  bool detailedView = false;
  bool measuring = false;
  List<double> wavelengths = [0, 0, 0, 0, 0, 0];
  List<int> wavelengthsSimplified = [0, 0, 0, 0, 0, 0];
  List<double> channels = [450, 500, 550, 570, 600, 650];
  late PolyFit p;
  bool hasRead = false;
  List<String> channelsText = ["V", "B", "G", "Y", "O", "R"];
  int wavelength = 0;
  List<ChartData> chartData = [];
  List<ChartData> regressionData = [];
  List<double> regressionY = [];
  List<double> regressionX = [];

  void interpretString() {
    // print(fullOutputRead);

    fullOutputRead = fullOutputRead.substring(fullOutputRead.indexOf("R")+1, fullOutputRead.indexOf("T"));
    // print(fullOutputRead);

    for (int i=0;i<5;i++) {
      wavelengths[i] = double.tryParse(fullOutputRead.substring(0, fullOutputRead.indexOf(";")))!;
      fullOutputRead = fullOutputRead.substring(fullOutputRead.indexOf(";")+1, fullOutputRead.length);
    }
    // print(fullOutputRead);
    wavelengths[5] = double.tryParse(fullOutputRead.substring(0, fullOutputRead.length < 5 ? fullOutputRead.length : 5))!;

    for (int i=0;i<5;i++) {
      wavelengthsSimplified[i] = int.parse(wavelengths[i].toStringAsFixed(0));
    }

    chartData.clear();

    for (int i=0;i<6;i++) {
      chartData.add(
        ChartData(channels[i], wavelengths[i])
      );
    }

    p = PolyFit(Array(channels), Array(wavelengths), maxDeg);

    //Dummy way to find local max: we are gonna predict for EVERY x-y value 💀💀

    //Humans see from 320 to 700 nanometer wavelengths
    //We will do 440-660 to avoid having strange data

    regressionY.clear();
    regressionData.clear();

    double localMax = 0;

    for (int i=0;i<=220;i++) {
      double current = (440+i).toDouble();
      double value = p.predict(current);
      if (value > localMax) {
        wavelength = current.toInt();
        localMax = value;
      }
      // print("Found $value for $current");

      // if (i%5 == 0)
        regressionData.add(ChartData(current, value));
    }

    hasRead = true;

    print(wavelength);


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
            ListTile(title: const Text('Contrôle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
            SwitchListTile(
              title: const Text('Lumière'),
              value: lightIsActive,
              onChanged: (bool value) {

                _sendMessage(!value ? "B" : "A");
                lightIsActive = value;

                setState(() {});
              },
            ),

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

            SizedBox(height: 20),

            ListTile(
              title: const Text('Analyse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              trailing: ElevatedButton(
                onPressed: () {
                  setState(() {
                    detailedView = !detailedView;
                  });
                },
                child:Text(detailedView ? "Afficher(-)" : "Afficher (+)")
              ),
            ),

            if (hasRead)
              Column(
                children: [
                  ListTile(
                    title: const Text('Mesure', style: TextStyle()),
                    subtitle: Text(detailedView ? channelsText.toString() : ""),
                    trailing: Text(detailedView ? wavelengths.toString() : wavelengthsSimplified.toString(), style: TextStyle(fontSize: detailedView ? 12 : 14)),
                  ),
                  ListTile(
                    title: const Text("Longueur d\'onde"),
                    trailing: Text(wavelength.toString()),
                  ),
                  ListTile(
                      title: const Text("Précision (R2)"),
                      subtitle: Text(detailedView? p.toString().substring(0, p.toString().indexOf("(")-1) : "", style: TextStyle(fontSize: 10)),
                      trailing: Text(detailedView ? p.R2().toString() : p.R2().toStringAsFixed(2))
                  ),
                ]
              ),

            SizedBox(height: 20),

            SizedBox(
              height: 400,
              child: SfCartesianChart(
                primaryXAxis: NumericAxis(
                  plotBands: <PlotBand> [
                    PlotBand(
                      start: wavelength,
                      end: wavelength,
                      isVisible: true,
                      borderWidth: 2,
                      borderColor: Colors.red,
                    )
                  ]
                ),
                series: <ChartSeries>[
                  SplineSeries<ChartData, double>(
                      dataSource: regressionData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      color: Colors.blue,
                  ),
                  ScatterSeries<ChartData, double>(
                      dataSource: chartData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      color: Colors.black,
                  ),
                ],
              ),
            ),
            Text('Chaîne (μW/cm2)'),

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
