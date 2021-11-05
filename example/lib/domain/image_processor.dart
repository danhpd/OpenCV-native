import 'dart:async';
import 'dart:isolate';
import 'package:opencv/native_library.dart';

class ImageProcessor {
  static Isolate? isolate;
  static ReceivePort? receivePort;
  static SendPort? sendPort;

  static Future<void> _cropImageIsolate(ProcessImageInput processImageInput) async {
    print('time1 ${new DateTime.now().millisecondsSinceEpoch - processImageInput.time!} ms');
    await NativeLibrary.cropImage(processImageInput.inputPath, processImageInput.edgeDetectionResult!);
    print('time2 ${new DateTime.now().millisecondsSinceEpoch - processImageInput.time!} ms');
    processImageInput.sendPort.send(true);
  }

  static Future<bool> cropImage(String filePath, EdgeDetectionResult edgeDetectionResult) async {
    int start = new DateTime.now().millisecondsSinceEpoch;
    final port = ReceivePort();
    Isolate.spawn(
        _cropImageIsolate,
        ProcessImageInput(
            inputPath: filePath,
            edgeDetectionResult: edgeDetectionResult,
            sendPort: port.sendPort,
            time: start
        ),
    );
    return await _subscribeToPort<bool>(port);
  }

  static Future<void> _convertToBwIsolate(ProcessImageInput processImageInput) async {
    print('time1 ${new DateTime.now().millisecondsSinceEpoch - processImageInput.time!} ms');
    await NativeLibrary.convertToBW(processImageInput.inputPath, processImageInput.destPath!);
    print('time2 ${new DateTime.now().millisecondsSinceEpoch - processImageInput.time!} ms');
    processImageInput.sendPort.send(true);
  }

  static Future<bool> convertToBw(String filePath, String destPath) async {
    int start = new DateTime.now().millisecondsSinceEpoch;
    final port = ReceivePort();
    Isolate.spawn(
      _convertToBwIsolate,
        ProcessImageInput(
          destPath: destPath,
          inputPath: filePath,
          sendPort: port.sendPort,
          time: start
        ),
    );
    return await _subscribeToPort<bool>(port);
  }

  static Future<void> _compressImageIsolate(ProcessImageInput input) async {
    print('time1 ${new DateTime.now().millisecondsSinceEpoch - input.time!} ms');
    await NativeLibrary.compressImage(input.inputPath, input.destPath!, input.maxWidth!, input.quality!, 0);
    print('time2 ${new DateTime.now().millisecondsSinceEpoch - input.time!} ms');
    input.sendPort.send(true);
  }
  static Future<void> _compressImageIsolate2(ProcessImageInput input) async {
    print('time1 ${new DateTime.now().millisecondsSinceEpoch - input.time!} ms');
    await NativeLibrary.compressImage(input.inputPath, input.destPath!, input.maxWidth!, input.quality!, 0);
    print('time2 ${new DateTime.now().millisecondsSinceEpoch - input.time!} ms');
  }

  static Future<bool> compressImage(String filePath, String destPath, int maxWidth, int quality) async {
    int start = new DateTime.now().millisecondsSinceEpoch;
    final port = ReceivePort();
    // await compute(_compressImageIsolate2,
    //     ProcessImageInput(
    //         destPath: destPath,
    //         inputPath: filePath,
    //         sendPort: port.sendPort,
    //         maxWidth: maxWidth,
    //         quality: quality,
    //         time: start
    //     ));
    // return true;
    Isolate.spawn(
      _compressImageIsolate,
        ProcessImageInput(
          destPath: destPath,
          inputPath: filePath,
          sendPort: port.sendPort,
          maxWidth: maxWidth,
          quality: quality,
          time: start
        ),
    );
    return await _subscribeToPort<bool>(port);
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

class ProcessImageInput {
  ProcessImageInput({
    required this.inputPath,
    this.edgeDetectionResult,
    required this.sendPort,
    this.destPath,
    this.maxWidth,
    this.quality,
    this.time
  });

  String inputPath;
  String? destPath;
  EdgeDetectionResult? edgeDetectionResult;
  SendPort sendPort;
  int? maxWidth;
  int? quality;
  int? time;
}