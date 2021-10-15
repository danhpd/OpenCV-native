import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:opencv/edge_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'cropping_preview.dart';
import 'edge_detector.dart';
import 'package:image/image.dart' as imglib;

import 'image_converter.dart';

typedef convert_func = Pointer<Uint32> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef Convert = Pointer<Uint32> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, int, int, int, int);

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: SafeArea(child: TakePictureScreen()),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({Key? key}) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<String> _initializeControllerFuture;
  late CameraDescription _cameraDescription;
  StreamController streamController = new StreamController<Rect>();
  bool isProcessing = false;
  String filePath = '';
  Rect? rect = null;
  String text = 'd';
  bool isInited = false;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    //initCam();
    setPath();
    _initializeControllerFuture = initCam();
  }

  Future<String> initCam() async {
    final cameras = await availableCameras();
    _cameraDescription = cameras.first;
    // Get a specific camera from the list of available cameras.
    _controller = CameraController(
      _cameraDescription,
      ResolutionPreset.veryHigh,
    );
    await _controller.initialize();
    _controller.startImageStream(_processCameraImage);
    setState(() {
      isInited = true;
    });
    return 'ok';
  }

  Future _processCameraImage(CameraImage cameraImage) async {
    if (isProcessing) return;
    isProcessing = true;
    //pause1s();
    //await Future.delayed(Duration(milliseconds: 1000));
    try {
      convertImage(cameraImage);

      // List<int>? data = await convertImagetoPng(_savedImage);
      // print('lengc ${data!.first}');

      // if(data!=null) {
      //   imglib.Image? ig = imglib.decodeImage(data);
      //   print('lengc ${ig!.width}');
      // }
      //
      //
      //   final Directory extDir = await getTemporaryDirectory();
      //   final String filePath = '${extDir.path}/image.jpg';
      //   File file = File(filePath);
      //   file.createSync();
      //   file.writeAsBytesSync(data);
      //   int length = file.lengthSync();
      //   print('leng2 $length');
      //   Image imm = Image.memory(Uint8List.fromList(data));
      //   double? d = imm.width;
      //   print('leng3 $d');
      // }
      //

    } catch (e) {
      String s = e.toString();
      print('exception $s');
      // await handleExepction(e)
    } finally {}
  }

  Future setPath() async {
    final Directory extDir = await getTemporaryDirectory();
    filePath = '${extDir.path}/image.jpg';
  }

  SendPort? sendPort;
  Isolate? isolate = null;
  var receivePort;
  int start = 0;

  void convertImage(CameraImage cameraImage) async {
    start = new DateTime.now().millisecondsSinceEpoch;
    if(isolate==null) {
      receivePort = ReceivePort();
      isolate = await Isolate.spawn(
          convertImageIsolate,
          ImageInput(
              cameraImage: cameraImage,
              path: filePath,
              sendPort: receivePort.sendPort,
              startTime: start));
      receivePort.listen((message) async {
        //isProcessing = false;
        if(sendPort ==null) sendPort = message;
        print('time3 ${new DateTime.now().millisecondsSinceEpoch - start}');
        if (filePath.length == 0) {
          isProcessing = false;
          return;
        }
        EdgeDetector.detectEdges(filePath,(EdgeDetectionResult result){
          rect = Rect.fromLTRB(result.topLeft.dx, result.topLeft.dy,
              result.topRight.dx, result.bottomRight.dy);
          //streamController.sink.add(rect);
          print('time4 ${new DateTime.now().millisecondsSinceEpoch - start}');
          text = 'time ${new DateTime.now().millisecondsSinceEpoch - start}';
          isProcessing = false;
          setState(() {});
        });
      });
    } else {
      sendPort!.send(ImageInput(
          cameraImage: cameraImage,
          path: filePath,
          sendPort: receivePort.sendPort,
          startTime: start));
    }
  }

  static void convertImageIsolate(ImageInput imageInput) async {
    var receivePort = ReceivePort();
    receivePort.listen((message) async {
      print('ttt ${new DateTime.now().millisecondsSinceEpoch - message.startTime}');
      imglib.Image image = await ImageConverter.YUV420toRGB(message.cameraImage);
      print('ttt1 ${new DateTime.now().millisecondsSinceEpoch - message.startTime}');
      File file = File(message.path);
      file.writeAsBytesSync(imglib.encodeJpg(image));
      print('ttt2 ${new DateTime.now().millisecondsSinceEpoch - message.startTime}');
      //print('leng file ${file.lengthSync()}');
      imageInput.sendPort.send(message.sendPort);

    });
    imageInput.sendPort.send(receivePort.sendPort);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    streamController.close();
    super.dispose();
  }

  Future<void> startCapture() async {
    // try {
    //   await _initializeControllerFuture;
    //   XFile image = await _controller.takePicture();
    //   EdgeDetectionResult result = await EdgeDetector().detectEdges(image.path);
    //   rect = Rect.fromLTRB(result.topLeft.dx, result.topLeft.dy,
    //       result.topRight.dx, result.bottomRight.dy);
    //   //streamController.sink.add(rect);
    //   setState(() {});
    //   print('add sink');
    // } catch (e) {
    //   print(e);
    // }
  }

  Widget _getPainterView() {
    if (rect == null) return Text('Loading...');
    return CustomPaint(
      foregroundPainter: RectanglePainter(rect!),
      child: Container(),
    );
    // StreamBuilder(
    //   stream: streamController.stream,
    //   builder: (context, snapshot) {
    //     print('StreamBuilder $snapshot');
    //     if (snapshot.hasData) {
    //
    //     } else
    //
    //   },
    // )
  }

  @override
  Widget build(BuildContext context) {
    print('build view');
    return Scaffold(
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: Stack(children: [
        isInited ? CameraPreview(_controller) : CircularProgressIndicator(),
        _getPainterView(),
        Text(text)
      ]),
      // floatingActionButton: FloatingActionButton(
      //   // Provide an onPressed callback.
      //   onPressed: startCapture,
      //   child: const Icon(Icons.camera_alt),
      // ),
    );
  }
}

class ImageConverter {
  static DynamicLibrary convertImageLib = Platform.isAndroid
      ? DynamicLibrary.open("libconvertImage.so")
      : DynamicLibrary.process();
  static Convert conv = convertImageLib
      .lookup<NativeFunction<convert_func>>('convertImage')
      .asFunction<Convert>();

  static Future<imglib.Image> YUV420toRGB(CameraImage _savedImage) async {
    // String s = _savedImage.format.group.toString();
    // int i = _savedImage.height;
    // int j = _savedImage.width;
    // print('aaaa $s $j x $i');
    // Allocate memory for the 3 planes of the image
    Pointer<Uint8> p = calloc(_savedImage.planes[0].bytes.length);
    Pointer<Uint8> p1 = calloc(_savedImage.planes[1].bytes.length);
    Pointer<Uint8> p2 = calloc(_savedImage.planes[2].bytes.length);

    // Assign the planes data to the pointers of the image
    Uint8List pointerList = p.asTypedList(_savedImage.planes[0].bytes.length);
    Uint8List pointerList1 = p1.asTypedList(_savedImage.planes[1].bytes.length);
    Uint8List pointerList2 = p2.asTypedList(_savedImage.planes[2].bytes.length);
    pointerList.setRange(
        0, _savedImage.planes[0].bytes.length, _savedImage.planes[0].bytes);
    pointerList1.setRange(
        0, _savedImage.planes[1].bytes.length, _savedImage.planes[1].bytes);
    pointerList2.setRange(
        0, _savedImage.planes[2].bytes.length, _savedImage.planes[2].bytes);

    // Call the convertImage function and convert the YUV to RGB
    Pointer<Uint32> imgP = conv(
        p,
        p1,
        p2,
        _savedImage.planes[1].bytesPerRow,
        _savedImage.planes[1].bytesPerPixel!,
        _savedImage.width,
        _savedImage.height);
    // Get the pointer of the data returned from the function to a List
    List imgData = imgP.asTypedList((_savedImage.width * _savedImage.height));

    // Generate image from the converted data
    imglib.Image img = imglib.Image.fromBytes(
        _savedImage.height, _savedImage.width, imgData as List<int>);
    // int ii = img.height;
    // int jj = img.width;
    // print('img $jj $ii');

    // Free the memory space allocated
    // from the planes and the converted data
    calloc.free(p);
    calloc.free(p1);
    calloc.free(p2);
    calloc.free(imgP);

    // final Directory extDir = await getTemporaryDirectory();
    // final String filePath = '${extDir.path}/image.jpg';
    // File file = File(filePath);
    // file.writeAsBytesSync(imglib.encodePng(img));
    // print('leng file ${file.lengthSync()}');
    return img;
  }
}

class ImageInput {
  ImageInput(
      {required this.cameraImage, required this.path, required this.sendPort, required this.startTime});
  CameraImage cameraImage;
  SendPort sendPort;
  String path;
  int startTime;
}

// class DisplayPictureScreen extends StatefulWidget {
//   final String imagePath;
//
//   DisplayPictureScreen({Key? key, required this.imagePath}) : super(key: key);
//
//   @override
//   _DisplayPictureScreenState createState() => _DisplayPictureScreenState();
// }
//
// class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
//   EdgeDetectionResult? edgeDetectionResult = null;
//   String? croppedImagePath = null;
//
//   Future _detectEdges(String filePath) async {
//     EdgeDetectionResult result = await EdgeDetector().detectEdges(filePath);
//     print(result.toString());
//     print(result.topLeft);
//     print(result.topRight);
//     print(result.bottomLeft);
//     print(result.bottomRight);
//     setState(() {
//       edgeDetectionResult = result;
//     });
//   }
//
//   Future _processImage(
//       String filePath, EdgeDetectionResult edgeDetectionResult) async {
//     bool result =
//         await EdgeDetector().processImage(filePath, edgeDetectionResult);
//
//     if (result == false) {
//       return;
//     }
//     setState(() {
//       imageCache!.clearLiveImages();
//       imageCache!.clear();
//       croppedImagePath = filePath;
//     });
//   }
//
//   Widget _getMainView() {
//     if (croppedImagePath != null)
//       return Center(
//           child: PhotoView(
//         imageProvider: FileImage(File(croppedImagePath!)),
//       ));
//     if (edgeDetectionResult == null)
//       return Center(child: Image.file(File(widget.imagePath)));
//     return ImagePreview(
//       imagePath: widget.imagePath,
//       edgeDetectionResult: edgeDetectionResult!,
//     );
//   }
//
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _detectEdges(widget.imagePath);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // The image is stored as a file on the device. Use the `Image.file`
//       // constructor with the given path to display the image.
//       body: _getMainView(),
//       floatingActionButton: FloatingActionButton(
//         child: Icon(Icons.check),
//         onPressed: () {
//           if (croppedImagePath == null) {
//             _processImage(widget.imagePath, edgeDetectionResult!);
//           }
//         },
//       ),
//     );
//   }
// }

class RectanglePainter extends CustomPainter {
  RectanglePainter(this.elements);
  final Rect elements;

  @override
  void paint(Canvas canvas, Size size) {
    print('paint $elements');
    Rect scaleRect(Rect container) {
      return Rect.fromLTRB(
        container.left * size.width,
        container.top * size.height,
        container.right * size.width,
        container.bottom * size.height,
      );
    }

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.green
      ..strokeWidth = 2.0;

    canvas.drawRect(scaleRect(elements), paint);
  }

  @override
  bool shouldRepaint(RectanglePainter oldDelegate) {
    return true;
  }
}
