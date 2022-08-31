import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import './backrounded_button.dart';
import 'dart:convert';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';
import 'package:usb_serial/transaction.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:device_info/device_info.dart';
import './dataSpot.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

enum _deviceState {
  Connected,
  Connecing,
  Failed_port,
  Disconnected,
}

class _MyAppState extends State<MyApp> {
  Future? _lang;
  String _currentLang = "hungarian";

  UsbPort? _port;
  _deviceState _status = _deviceState.Disconnected;
  List<UsbDevice> _ports = [];
  List<String> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;
  List<DataSpot> _graphSpots = [];
  bool _isRecording = false;
  int _time = 0;
  Color _linecolor = Colors.green;
  Map<int, String> _recordedValues = {};

  Future<bool> _connectTo(device) async {
    _serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = _deviceState.Disconnected;
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = _deviceState.Failed_port;
      });
      return false;
    }
    setState(() {
      _status = _deviceState.Connecing;
      _graphSpots.clear();
      _serialData.clear();
    });
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        _status = _deviceState.Connected;
        _serialData.add(line);

        if (_graphSpots.length > 9) {
          _graphSpots.removeAt(0);
        }
        if (_isRecording) {
          _recordedValues[_time.toInt()] = line;
        }
        _graphSpots.add(DataSpot(_time, double.parse(line)));
        _time++;
      });
    });
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
    devices.forEach((device) {
      _ports.add(device);
      _connectTo(device);
    });
  }

  void dispose() {
    super.dispose();
    _connectTo(null); 
  }

  void SetRecording(bool status) async {
    if (status) {
      _time = 0;
      _graphSpots.clear();
      _recordedValues.clear();
      _isRecording = true;
      _linecolor = Colors.red;
    } else {
      _isRecording = false;
      _linecolor = Colors.green;
    }
  }

  void Saveresults() async {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    if (int.parse(androidInfo.version.release) > 10) {
      if (Permission.manageExternalStorage != PermissionStatus.granted) {
        Permission.manageExternalStorage.request();
      } //if user not grants permission the app cannot function. Needs a fix 
    } else {
      if (Permission.storage != PermissionStatus.granted) {
        Permission.storage.request();
      }
    }

    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      int n = 1;
      var excel = Excel.createExcel();
      excel.updateCell('Sheet1', CellIndex.indexByString("B1"),
          "Voltage:"); //locale this!!44!!!
      excel.updateCell('Sheet1', CellIndex.indexByString("A1"), "Time:");
      _recordedValues.forEach((key, value) {
        n++;
        excel.updateCell('Sheet1', CellIndex.indexByString("A${n}"), key);
        excel.updateCell('Sheet1', CellIndex.indexByString("B${n}"), value);
      });
      File("${result}/test.xlsx")
        ..createSync(recursive: false)
        ..writeAsBytesSync(excel.encode()!);
    }
  }

  Future readLangJsonFile() async {
    String input = await DefaultAssetBundle.of(context)
        .loadString('assets/languages.json');
    var map = jsonDecode(input);
    return map;
  }

  @override
  void initState() {
    super.initState();
    _lang = readLangJsonFile();

    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });
    _getPorts();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: _lang,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          Map<String, dynamic> _languages = snapshot.data[_currentLang];
          if (snapshot.connectionState == ConnectionState.done) {
            return Scaffold(
                appBar: AppBar(
                  title: Text(_languages["title"]),
                  backgroundColor: Colors.green,
                  actions: [
                    BackrButton(() {
                      setState(() {
                        _currentLang = "hungarian";
                      });
                    }, 'assets/hu.png'),
                    BackrButton(() {
                      setState(() {
                        _currentLang = "english";
                      });
                    }, 'assets/eng.png'),
                  ],
                ),
                body: Container(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Text(_languages["dev_con"],
                            style: Theme.of(context).textTheme.headline6),
                        Text((() {
                          switch (_status) {
                            case _deviceState.Connected:
                              {
                                return _languages["connect"];
                              }
                            case _deviceState.Connecing:
                              {
                                return _languages["connecting"];
                              }
                            case _deviceState.Failed_port:
                              {
                                return _languages["failed_port"];
                              }
                            default:
                              {
                                return _languages["disconnect"];
                              }
                          }
                        })(),
                            style: TextStyle(
                                color: (() {
                                  switch (_status) {
                                    case _deviceState.Connected:
                                      {
                                        return Colors.green;
                                      }
                                    case _deviceState.Connecing:
                                      {
                                        return Colors.blue;
                                      }
                                    default:
                                      {
                                        return Colors.red;
                                      }
                                  }
                                }()),
                                fontSize: 15)),
                        Text(_languages["now_data"], style: Theme.of(context).textTheme.headline6),
                        _serialData.isNotEmpty
                            ? Text("${_serialData[_serialData.length - 1]} mV", style: TextStyle(color: _isRecording ? Colors.red: Colors.black))
                            : Text(
                                _languages["no_data_yet"],
                                style: TextStyle(color: Colors.grey),
                              ),
                        //Expanded(child: ChartGraph(_graphSpots, _linecolor, _languages["time"], _languages["volt"])),
                        Container(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                    child: Text(_languages["start"]),
                                    onPressed:
                                        (_status == _deviceState.Connected &&
                                                !_isRecording)
                                            ? () {
                                                print(_status ==
                                                    _deviceState.Connected);
                                                print(_isRecording);
                                                setState(() {
                                                  SetRecording(true);
                                                });
                                              }
                                            : null,
                                    style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all<Color>(
                                                Colors.green))),
                                ElevatedButton(
                                    child: Text(_languages["stop"]),
                                    onPressed: _isRecording
                                        ? () {
                                            setState(() {
                                              SetRecording(false);
                                            });
                                          }
                                        : null,
                                    style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStateProperty.all<Color>(
                                                Colors.red))),
                              ],
                            )),
                        ElevatedButton(
                            child: Text(_languages["export"]),
                            onPressed:
                                (_recordedValues.isNotEmpty && !_isRecording)
                                    ? Saveresults
                                    : null,
                            style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(
                                        Color.fromARGB(255, 0, 141, 32)))),
                      ],
                    )));
          } else {
            return Text(
              "Error Failed to load languages.json!",
              style: TextStyle(color: Colors.red),
            );
          }
        },
      ),
    );
  }
}
