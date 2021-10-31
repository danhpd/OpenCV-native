import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:opencv/native_library.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'cropping_preview.dart';
import 'edge_detector.dart';
import 'image_processor.dart';

class PreviewEditScreen extends StatefulWidget {
  final String imagePath;

  PreviewEditScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _DisplayPictureScreenState createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<PreviewEditScreen> {
  EdgeDetectionResult? edgeDetectionResult;
  String? croppedImagePath;
  var pdf;

  @override
  void initState() {
    super.initState();
    _detectEdge();
    //pdf = pw.Document();
    // var image = pw.MemoryImage(
    //   File(widget.imagePath).readAsBytesSync(),
    // );
    // pdf.addPage(pw.Page(build: (pw.Context context) {
    //   return pw.Center(
    //     child: pw.Image(image),
    //   ); // Center
    // }));
  }

  _detectEdge() async {
    edgeDetectionResult =
        await EdgeDetector.detectEdgesByImagePath(widget.imagePath);
    // edgeDetectionResult = EdgeDetectionResult(
    //   topLeft: Offset(0, 0),
    //   topRight: Offset(1, 0),
    //   bottomRight: Offset(1, 1),
    //   bottomLeft: Offset(0, 1),
    // );
    setState(() {});
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/counter.pdf');
  }

  bool isProcessing = false;
  Future _processImage(String filePath, EdgeDetectionResult eresult) async {
    setState(() {
      isProcessing = true;
    });
    int start = new DateTime.now().millisecondsSinceEpoch;
    bool result = await ImageProcessor.cropImage(filePath, eresult);
    await ImageProcessor.compressImage(filePath, filePath, 1000, 12);

    print(
        'cropImage time ${new DateTime.now().millisecondsSinceEpoch - start} ms');

    if (result == false) {
      return;
    }

    print('length cropped ${File(filePath).lengthSync()}');
    // var image = pw.MemoryImage(
    //   File(filePath).readAsBytesSync(),
    // );
    // pdf.addPage(pw.Page(build: (pw.Context context) {
    //   return pw.Center(
    //     child: pw.Image(image),
    //   ); // Center
    // }));
    //
    // final file = await _localFile;
    // await file.writeAsBytes(await pdf.save());
    // print('pdf ${pdf.toString()}');
    // print('pdf ${file.path}');

    //print('length cropped ${file.lengthSync()}');
    //Image image = Image.file(File(filePath));
    //print('size ${image.width}x${image.height}');
    setState(() {
      isProcessing = false;
      imageCache!.clearLiveImages();
      imageCache!.clear();
      croppedImagePath = filePath;
    });
    Share.shareFiles([filePath], text: 'Great picture');
  }

  Widget _getAppBar() {
    String dropdownValue = 'One';
    return Container(
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(onPressed: () {}, child: Icon(Icons.chevron_left)),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: dropdownValue,
              icon: const Icon(Icons.keyboard_arrow_down_sharp),
              iconSize: 24,
              elevation: 16,
              dropdownColor: Colors.blue,
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              underline: Container(
                height: 2,
                color: Colors.white10,
              ),
              onChanged: (String? newValue) {
                setState(() {
                  dropdownValue = newValue!;
                });
              },
              items: <String>['One', 'Two', 'Free', 'Four']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(onPressed: () {}, child: Icon(Icons.rotate_right)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(onPressed: () {}, child: Icon(Icons.invert_colors)),
          ),
        ],
      ),
    );
  }

  Widget _getBottomBar() {
    return Container(
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(onPressed: () {}, child: Icon(Icons.image)),
          isProcessing
              ? Container(
                  child: Center(
                      child: CircularProgressIndicator(
                  color: Colors.white,
                )))
              : ElevatedButton(
                  onPressed: () {
                    if (croppedImagePath == null) {
                      _processImage(widget.imagePath, edgeDetectionResult!);
                    }
                  },
                  child: Icon(Icons.flip_camera_ios)),
          ElevatedButton(onPressed: () {}, child: Icon(Icons.add_circle)),
        ],
      ),
    );
  }

  Widget _getMainView() {
    if (croppedImagePath != null)
      return PhotoView(
        imageProvider: FileImage(File(croppedImagePath!)),
      );
    if (edgeDetectionResult != null) {
      return ImagePreview(
        imagePath: widget.imagePath,
        edgeDetectionResult: edgeDetectionResult!,
      );
    }
    return Image(image: FileImage(File(widget.imagePath)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Scaffold(
          // The image is stored as a file on the device. Use the `Image.file`
          // constructor with the given path to display the image.
          body: Column(
            children: [
              _getAppBar(),
              Expanded(child: _getMainView()),
              _getBottomBar()
            ],
          ),
        ),
      ),
    );
  }
}
