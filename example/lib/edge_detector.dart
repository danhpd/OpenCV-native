import 'dart:async';
import 'dart:isolate';

import 'package:opencv/edge_detection.dart';

class EdgeDetector {
  static Isolate? isolate;
  static ReceivePort? receivePort = null;
  static SendPort? sendPort;

  static Future<void> startEdgeDetectionIsolate(EdgeDetectionInput edgeDetectionInput) async {
    receivePort = ReceivePort();
    receivePort!.listen((message) async {
      EdgeDetectionResult result = await EdgeDetection.detectEdges(message.inputPath);
      message.sendPort.send([receivePort!.sendPort,result]);
    });
    EdgeDetectionResult result = await EdgeDetection.detectEdges(edgeDetectionInput.inputPath);
    edgeDetectionInput.sendPort.send([receivePort!.sendPort,result]);
  }

  static Future<void> processImageIsolate(ProcessImageInput processImageInput) async {
    EdgeDetection.processImage(processImageInput.inputPath, processImageInput.edgeDetectionResult);
    processImageInput.sendPort.send(true);
  }

  static Future detectEdges(String filePath, Function? function (EdgeDetectionResult resul)) async {
    if(isolate==null){
      receivePort = ReceivePort();
      receivePort!.listen((message) {
        if(sendPort==null) sendPort = message[0];
        function(message[1]);
      });
      isolate = await _spawnIsolate<EdgeDetectionInput>(
          startEdgeDetectionIsolate,
          EdgeDetectionInput(
              inputPath: filePath,
              sendPort: receivePort!.sendPort
          ),
          receivePort!
      ) as Isolate?;
    }
    else {
      sendPort!.send(EdgeDetectionInput(
          inputPath: filePath,
          sendPort: receivePort!.sendPort
      ));
    }
  }

  Future<bool> processImage(String filePath, EdgeDetectionResult edgeDetectionResult) async {
    final port = ReceivePort();

    _spawnIsolate<ProcessImageInput>(
      processImageIsolate,
      ProcessImageInput(
        inputPath: filePath,
        edgeDetectionResult: edgeDetectionResult,
        sendPort: port.sendPort
      ),
      port
    );

    return await _subscribeToPort<bool>(port);
  }

  static Future<Isolate> _spawnIsolate<T>(Function(T) function, dynamic input, ReceivePort port) {
    return Isolate.spawn<T>(
      function,
      input,
      onError: port.sendPort,
      onExit: port.sendPort
    );
  }

  Future<T> _subscribeToPort<T>(ReceivePort port) async {
    StreamSubscription? sub;
    
    var completer = new Completer<T>();
    
    sub = port.listen((result) async {
      await sub!.cancel();
      completer.complete(await result);
    });
    
    return completer.future;
  }
}

class EdgeDetectionInput {
  EdgeDetectionInput({
    required this.inputPath,
    required this.sendPort
  });

  String inputPath;
  SendPort sendPort;
}

class ProcessImageInput {
  ProcessImageInput({
    required this.inputPath,
    required this.edgeDetectionResult,
    required this.sendPort
  });

  String inputPath;
  EdgeDetectionResult edgeDetectionResult;
  SendPort sendPort;
}