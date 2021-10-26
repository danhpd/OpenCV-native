import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:opencv/native_library.dart';

class EdgeDetector {
  static Isolate? isolate;
  static ReceivePort? receivePort;
  static SendPort? sendPort;

  static Future<EdgeDetectionResult> detectEdgesByImagePath(String filePath) async {
    final port = ReceivePort();
    Isolate.spawn(
        startEdgeDetectionIsolatePath,
        EdgeDetectionInput(
            inputPath: filePath,
            sendPort: port.sendPort
        )
    );
    return await _subscribeToPort<EdgeDetectionResult>(port);
  }

  static Future<void> startEdgeDetectionIsolatePath(EdgeDetectionInput edgeDetectionInput) async {
    EdgeDetectionResult result = await NativeLibrary.detectEdgesByImagePath(edgeDetectionInput.inputPath!);
    edgeDetectionInput.sendPort.send(result);
  }

  static Future detectEdgesByCameraImage(CameraImage cameraImage, Function? function (EdgeDetectionResult resul)) async {
    if(isolate==null){
      receivePort = ReceivePort();
      receivePort!.listen((message) {
        if(message==null) return;
        if(sendPort==null) sendPort = message[0];
        if(message[1] is EdgeDetectionResult) function(message[1]);
      });
      isolate = await Isolate.spawn(startEdgeDetectionIsolateCamera, EdgeDetectionInput(
          cameraImage: cameraImage,
          sendPort: receivePort!.sendPort
      ));
    }
    else {
      sendPort!.send(EdgeDetectionInput(
          cameraImage: cameraImage,
          sendPort: receivePort!.sendPort
      ));
    }
  }

  static Future<void> startEdgeDetectionIsolateCamera(EdgeDetectionInput edgeDetectionInput) async {
    receivePort = ReceivePort();
    receivePort!.listen((message) async {
      //print('startEdgeDetectionIsolate2 ${message.cameraImage.width}x${message.cameraImage.height}');
      EdgeDetectionResult result = await NativeLibrary.detectEdgesByCameraImage(message.cameraImage);
      message.sendPort.send([receivePort!.sendPort,result]);
    });
    EdgeDetectionResult result = await NativeLibrary.detectEdgesByCameraImage(edgeDetectionInput.cameraImage!);
    edgeDetectionInput.sendPort.send([receivePort!.sendPort,result]);
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
    this.inputPath,
    this.cameraImage,
    required this.sendPort
  });

  String? inputPath;
  SendPort sendPort;
  CameraImage? cameraImage;
}