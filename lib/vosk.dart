import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

class VoskView extends StatefulWidget {
  const VoskView({Key? key}) : super(key: key);

  @override
  State<VoskView> createState() => _VoskViewState();
}

class _VoskViewState extends State<VoskView> {
  static const _textStyle = TextStyle(fontSize: 30, color: Colors.black);

  //static const _modelName = 'vosk-model-small-en-us-0.15';
  //static const _modelName = 'vosk-model-ar-mgb2-0.4';
  static const _sampleRate = 16000;
  static const _modelsNames = [
    VoskModel(name: "vosk-model-small-en-us-0.15", id: 1, title: "English"),
    VoskModel(name: "vosk-model-ar-mgb2-0.4", id: 2, title: "Arabic"),
  ];

  String? _modelName;
  final _vosk = VoskFlutterPlugin.instance();
  final _modelLoader = ModelLoader();
  final _recorder = Record();

  String _fileRecognitionResult = "";
  String? _error;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _recognitionStarted = false;
  bool _isLoadingModel = false;

  @override
  void initState() {
    super.initState();
    print("*** models list ***");
    _modelLoader.loadModelsList().then((models) {
      models.forEach((element) {
        print("***");
        print("name: ${element.name}");
        print("url: ${element.url}");
      });
    });
  }

  set isLoadingModel(bool val) {
    _isLoadingModel = val;
    setState(() {});
  }

  bool get isLoadingModel => _isLoadingModel;

  Future<void> initModel() async {
    if (_modelName == null) return;
    try {
      isLoadingModel = true;
      final models = await _modelLoader.loadModelsList();
      LanguageModelDescription? selectedModelDescription;
      for (final modelDescription in models) {
        if (modelDescription.name == _modelName) {
          selectedModelDescription = modelDescription;
          break;
        }
      }
      if (selectedModelDescription == null) {
        isLoadingModel = false;
        return;
      }
      String? cachedModelPath;
      final isModelLoaded =
          await _modelLoader.isModelAlreadyLoaded(selectedModelDescription.url);
      if (isModelLoaded) {
        cachedModelPath =
            await _modelLoader.modelPath(selectedModelDescription.name);
      } else {
        cachedModelPath =
            await _modelLoader.loadFromNetwork(selectedModelDescription.url);
      }
      _model = await _vosk.createModel(cachedModelPath);
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: _sampleRate,
      );
      if (Platform.isAndroid) {
        _speechService = await _vosk.initSpeechService(
          _recognizer!,
        );
      }
    } catch (e) {
      _error = e.toString();
    }
    isLoadingModel = false;
    setState(() {});
  }

  @override
  void dispose() {
    _speechService?.cancel();
    _speechService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vosk"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Builder(
            builder: (context) {
              if (_error != null) {
                return Center(child: Text("Error: $_error", style: _textStyle));
              } else if (_model == null && !isLoadingModel) {
                return const Center(
                    child: Text("Select Language...", style: _textStyle));
              } else if (isLoadingModel) {
                return const Center(
                    child: Text("Loading model...", style: _textStyle));
              } else if (Platform.isAndroid && _speechService == null) {
                return const Center(
                  child:
                      Text("Initializing speech service...", style: _textStyle),
                );
              } else {
                return Platform.isAndroid
                    ? _androidExample()
                    : _commonExample();
              }
            },
          ),
          const SizedBox(
            height: 12,
          ),
          isLoadingModel || (_recognitionStarted)
              ? const SizedBox()
              : Row(
                  children: [
                    const Text('Language: '),
                    Flexible(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        onChanged: (selectedVal) {
                          _modelName = selectedVal;
                          initModel();
                          setState(() {});
                        },
                        value: _modelName,
                        items: _modelsNames
                            .map(
                              (localeName) => DropdownMenuItem(
                                value: localeName.name,
                                child: Text(localeName.title),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _androidExample() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Partial result: ",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(
                    height: 12,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(4),
                      child: StreamBuilder(
                          stream: _speechService!.onPartial(),
                          builder: (context, snapshot) {
                            final data = snapshot.data == null
                                ? null
                                : json.decode(snapshot.data!);
                            final partialResult = data?["partial"] ?? "";
                            return Text(
                              "${partialResult}",
                            );
                          }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Final Result: ",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(
                    height: 12,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(4),
                      child: StreamBuilder(
                          stream: _speechService!.onResult(),
                          builder: (context, snapshot) {
                            final data = snapshot.data == null
                                ? null
                                : json.decode(snapshot.data!);
                            final finalRes = data?["text"] ?? "";
                            if (finalRes.toString().trim().isNotEmpty) {
                              _fileRecognitionResult =
                                  "$_fileRecognitionResult " + finalRes;
                            }
                            return Text(
                              _fileRecognitionResult,
                            );
                          }),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    _fileRecognitionResult = "";
                    if (_recognitionStarted) {
                      await _speechService!.stop();
                    } else {
                      await _speechService!.start();
                    }
                    setState(() => _recognitionStarted = !_recognitionStarted);
                  },
                  child: Text(_recognitionStarted
                      ? "Stop recognition"
                      : "Start recognition")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commonExample() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: () async {
                if (_recognitionStarted) {
                  await _stopRecording();
                } else {
                  await _recordAudio();
                }
                setState(() => _recognitionStarted = !_recognitionStarted);
              },
              child: Text(
                  _recognitionStarted ? "Stop recording" : "Record audio")),
          Text("Final recognition result: $_fileRecognitionResult",
              style: _textStyle),
        ],
      ),
    );
  }

  Future<void> _recordAudio() async {
    try {
      await _recorder.start(
          samplingRate: 16000, encoder: AudioEncoder.wav, numChannels: 1);
    } catch (e) {
      _error =
          '$e\n\n Make sure fmedia(https://stsaz.github.io/fmedia/) is installed on Linux';
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _recorder.stop();
      if (filePath != null) {
        final bytes = File(filePath).readAsBytesSync();
        _recognizer!.acceptWaveformBytes(bytes);
        _fileRecognitionResult = await _recognizer!.getFinalResult();
      }
    } catch (e) {
      _error =
          '$e\n\n Make sure fmedia(https://stsaz.github.io/fmedia/) is installed on Linux';
    }
  }
}

class VoskModel {
  final String name;
  final int id;
  final String title;

  const VoskModel({required this.name, required this.id, required this.title});
}
