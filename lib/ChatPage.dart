import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:color_models/color_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:ondes/helpers/Variables.dart';
import 'package:scidart/numdart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
  bool showColorPicker = false;
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

  num X=0, Y=0, Z=0; // XYZ
  num x=0, y=0, z=0; // xyz
  int R=0, G=0, B=0; // RGB
  num L=0, a=0, b=0; // Lab
  String hexidecimal = "";

  // ColorConverter colorConv = ColorConverter();

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

    num Gamma = 0.8, IntensityMax = 255, factor;
    if((wavelength >= 380) && (wavelength<440)){
      R = (-(wavelength - 440) / (440 - 380)).round();
      G = 0;
      B = 1;
    }else if((wavelength >= 440) && (wavelength<490)){
      R = 0;
      G = ((wavelength - 440) / (490 - 440)).round();
      B = 1;
    }else if((wavelength >= 490) && (wavelength<510)){
      R = 0;
      G = 1;
      B = (-(wavelength - 510) / (510 - 490)).round();
    }else if((wavelength >= 510) && (wavelength<580)){
      R = ((wavelength - 510) / (580 - 510)).round();
      G = 1;
      B = 0;
    }else if((wavelength >= 580) && (wavelength<645)){
      R = 1;
      G = (-(wavelength - 645) / (645 - 580)).round();
      B = 0;
    }else if((wavelength >= 645) && (wavelength<781)){
      R = 1;
      G = 0;
      B = 0;
    }else{
      R = 0;
      G = 0;
      B = 0;
    }
    // Let the intensity fall off near the vision limits
    if((wavelength >= 380) && (wavelength<420)){
      factor = 0.3 + 0.7*(wavelength - 380) / (420 - 380);
    }else if((wavelength >= 420) && (wavelength<701)){
      factor = 1.0;
    }else if((wavelength >= 701) && (wavelength<781)){
      factor = 0.3 + 0.7*(780 - wavelength) / (780 - 700);
    }else{
      factor = 0.0;
    };
    if (R != 0){
      R = (IntensityMax * pow(R * factor, Gamma)).round();
    }
    if (G != 0){
      G = (IntensityMax * pow(G * factor, Gamma)).round();
    }
    if (B != 0){
      B = (IntensityMax * pow(B * factor, Gamma)).round();
    }


    int adjWavelength = wavelength - 380; //Dataset starts @ 380
    // int remainder = adjWavelength%5;
    // if (remainder > 2) {
    //   adjWavelength = adjWavelength - (remainder) + 5;
    // } else {
    //   adjWavelength = adjWavelength - (remainder);
    // }
    // adjWavelength = (adjWavelength/5).round();


    X = ColorMatchingFunctions[adjWavelength]['X'];
    Y = ColorMatchingFunctions[adjWavelength]['Y'];
    Z = ColorMatchingFunctions[adjWavelength]['Z'];

    x = X / (X+Y+Z);
    y = Y / (X+Y+Z);
    z = Z / (X+Y+Z);

    //Color spaces:
    // (XYZ) ; (xyz) ; (xyY) https://stackoverflow.com/questions/3407942/rgb-values-of-visible-spectrum thanks!

    // XyzColor XYZ = XyzColor(x, y, z);
    // RgbColor RGB = ColorConverter.xyzToRgb(XYZ);
    // R = RGB.red; G = RGB.green; B = RGB.blue;
    // LabColor Lab = ColorConverter.xyzToLab(XYZ);
    RgbColor RGB = RgbColor(R, G, B);
    LabColor Lab = ColorConverter.rgbToLab(RGB);
    L = Lab.lightness; a = Lab.a;
    hexidecimal = RGB.hex;

    print(RGB.toString());

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
                  child: Text('${hexidecimal} 📄', style: TextStyle(color: Colors.black)),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: "$hexidecimal"));

                    final snackBar = SnackBar(
                      content: const Text('La couleur a été copiée'),
                      action: SnackBarAction(
                        label: 'OK',
                        onPressed: () {
                          // Some code to undo the change.
                        },
                      ),
                    );

                    // Find the ScaffoldMessenger in the widget tree
                    // and use it to show a SnackBar.
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  },
                ),
              ),
              trailing: Container(height: 30, width: 30, color: Color.fromRGBO(R, G, B, 1)),
            ),

            ListTile(
              title: const Text('RGB', style: TextStyle()),
              trailing: Text("($R, $G, $B, 255)", style: TextStyle(fontSize: 14)),
            ),

            ListTile(
              title: const Text('Lab', style: TextStyle()),
              trailing: Text(detailedView ? "($L, $a, $b)" : "(${L.toStringAsFixed(2)}, ${a.toStringAsFixed(2)}, ${b.toStringAsFixed(2)})", style: TextStyle(fontSize: detailedView ? 12 : 14)),
            ),

            Divider(),

            ListTile(
              title: const Text('Choisiseur de couleur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              trailing: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showColorPicker = !showColorPicker;
                    });
                  },
                  child:Text(showColorPicker ? "Cacher" : "Afficher")
              ),
            ),

            if (showColorPicker)
              ColorPicker(
                pickerColor: Color.fromRGBO(R, G, B, 1),
                onColorChanged: (Color value) {
                },
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
