import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:opencv/edge_detection.dart';

class EdgeDetector {
  static Isolate? isolate;
  static ReceivePort? receivePort = null;
  static SendPort? sendPort;

  static Future<EdgeDetectionResult> detectEdges(String filePath) async {
    final port = ReceivePort();

    _spawnIsolate<EdgeDetectionInput>(
        startEdgeDetectionIsolate,
        EdgeDetectionInput(
            inputPath: filePath,
            sendPort: port.sendPort
        ),
        port
    );

    return await _subscribeToPort<EdgeDetectionResult>(port);
  }

  static Future<void> startEdgeDetectionIsolate(EdgeDetectionInput edgeDetectionInput) async {
    EdgeDetectionResult result = await EdgeDetection.detectEdges(edgeDetectionInput.inputPath);
    edgeDetectionInput.sendPort.send(result);
  }

  static Future detectEdges2(CameraImage cameraImage, Function? function (EdgeDetectionResult resul)) async {
    if(isolate==null){
      receivePort = ReceivePort();
      receivePort!.listen((message) {
        if(message==null) return;
        if(sendPort==null) sendPort = message[0];
        if(message[1] is EdgeDetectionResult) function(message[1]);
      });
      isolate = await Isolate.spawn(startEdgeDetectionIsolate2, EdgeDetectionInput2(
          cameraImage: cameraImage,
          sendPort: receivePort!.sendPort
      ));
    }
    else {
      sendPort!.send(EdgeDetectionInput2(
          cameraImage: cameraImage,
          sendPort: receivePort!.sendPort
      ));
    }
  }

  static Future<void> startEdgeDetectionIsolate2(EdgeDetectionInput2 edgeDetectionInput) async {
    receivePort = ReceivePort();
    receivePort!.listen((message) async {
      //print('startEdgeDetectionIsolate2 ${message.cameraImage.width}x${message.cameraImage.height}');
      EdgeDetectionResult result = await EdgeDetection.detectEdges2(message.cameraImage);
      message.sendPort.send([receivePort!.sendPort,result]);
    });
    EdgeDetectionResult result = await EdgeDetection.detectEdges2(edgeDetectionInput.cameraImage);
    edgeDetectionInput.sendPort.send([receivePort!.sendPort,result]);
  }

  static Future<void> processImageIsolate(ProcessImageInput processImageInput) async {
    EdgeDetection.processImage(processImageInput.inputPath, processImageInput.edgeDetectionResult);
    processImageInput.sendPort.send(true);
  }

  static Future<bool> processImage(String filePath, EdgeDetectionResult edgeDetectionResult) async {
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

  static Future<T> _subscribeToPort<T>(ReceivePort port) async {
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

class EdgeDetectionInput2 {
  EdgeDetectionInput2({
    required this.cameraImage,
    required this.sendPort
  });

  CameraImage cameraImage;
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