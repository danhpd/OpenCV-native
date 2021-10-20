import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:opencv/edge_detection.dart';
import 'package:simple_edge_detection_example/preview_edit_screen.dart';
import 'edge_detector.dart';

main() {
  //WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: SafeArea(child: ScanScreen()),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  late CameraController _controller;
  late Future _initializeControllerFuture;
  StreamController streamController = new StreamController<EdgeDetectionResult>();
  bool isProcessing = false;
  bool isInited = false;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = initCam();

  }

  Future<String> initCam() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.ultraHigh,
    );
    await _controller.initialize();
    _controller.startImageStream(_processCameraImage);
    setState(() {
      isInited = true;
    });
    return 'ok';
  }

  int start = 0;
  Future _processCameraImage(CameraImage cameraImage) async {
    if (isProcessing) return;
    isProcessing = true;
    try {
      start = new DateTime.now().millisecondsSinceEpoch;
      EdgeDetector.detectEdges2(cameraImage, (EdgeDetectionResult result) {
        streamController.sink.add(result);
        isProcessing = false;
        //print('time ${new DateTime.now().millisecondsSinceEpoch - start} ms');
      });
    } catch (e) {
      print('exception $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    streamController.close();
    super.dispose();
  }

  Future<void> startCapture() async {
    try {
      setState(() {
        isCapturing = true;
      });
      await _initializeControllerFuture;
      await _controller.stopImageStream();
      //await _controller.pausePreview();
      XFile image = await _controller.takePicture();
      print('image path: ${image.path}');
      print('length ${await image.length()}');
      EdgeDetectionResult result = await EdgeDetector.detectEdges(image.path);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewEditScreen(
            imagePath: image.path,
            edgeDetectionResult: result,
          ),
        ),
      );
      //await _controller.resumePreview();
      await _controller.startImageStream(_processCameraImage);
      setState(() {
        isCapturing = false;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('build view');
    return Scaffold(
      body: Stack(children: [
        isInited ? CameraPreview(_controller) : CircularProgressIndicator(),
        StreamBuilder(
            stream: streamController.stream,
            builder: (context, snapshot) {
              //print('StreamBuilder $snapshot');
              if (isCapturing) return Container();
              else if (snapshot.hasData) {
                return CustomPaint(
                  foregroundPainter: RectanglePainter(snapshot.data as EdgeDetectionResult),
                  child: Container(),
                );
              } else
                return Container();
            }),
        if (isCapturing) Container(
            child: Center(child: CircularProgressIndicator()),
            color: Color.fromRGBO(0, 0, 0, 0.5),
        ),

      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: startCapture,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

class RectanglePainter extends CustomPainter {
  RectanglePainter(this._result);
  final EdgeDetectionResult _result;

  @override
  void paint(Canvas canvas, Size size) {
    //print('${_result.bottomLeft}');
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.green
      ..strokeWidth = 2.0;

    var path = Path();
    path.moveTo(_result.topLeft.dx*size.width, _result.topLeft.dy*size.height);
    path.lineTo(_result.topRight.dx*size.width, _result.topRight.dy*size.height);
    path.lineTo(_result.bottomRight.dx*size.width, _result.bottomRight.dy*size.height);
    path.lineTo(_result.bottomLeft.dx*size.width, _result.bottomLeft.dy*size.height);
    path.lineTo(_result.topLeft.dx*size.width, _result.topLeft.dy*size.height);
    canvas.drawPath(path, paint);

  }

  @override
  bool shouldRepaint(RectanglePainter oldDelegate) {
    return true;
  }

}
