import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:opencv/edge_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'cropping_preview.dart';
import 'edge_detector.dart';

class PreviewEditScreen extends StatefulWidget {
  final String imagePath;
  final EdgeDetectionResult edgeDetectionResult;

  PreviewEditScreen(
      {Key? key, required this.imagePath, required this.edgeDetectionResult})
      : super(key: key);

  @override
  _DisplayPictureScreenState createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<PreviewEditScreen> {
  String? croppedImagePath = null;
  var pdf = null;

  @override
  void initState(){
    super.initState();
    pdf = pw.Document();
    var image = pw.MemoryImage(
      File(widget.imagePath).readAsBytesSync(),
    );
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Center(
        child: pw.Image(image),
      ); // Center
    }));

  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/counter.pdf');
  }

  Future _processImage(
      String filePath, EdgeDetectionResult edgeDetectionResult) async {

    bool result =
    await EdgeDetector.processImage(filePath, edgeDetectionResult);

    if (result == false) {
      return;
    }

    print('length cropped ${File(filePath).lengthSync()}');
    var image = pw.MemoryImage(
      File(filePath).readAsBytesSync(),
    );

    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Center(
        child: pw.Image(image),
      ); // Center
    }));

    final file = await _localFile;
    await file.writeAsBytes(await pdf.save());
    print('pdf ${pdf.toString()}');
    print('pdf ${file.path}');

    print('length cropped ${file.lengthSync()}');
    //Image image = Image.file(File(filePath));
    //print('size ${image.width}x${image.height}');
    setState(() {
      imageCache!.clearLiveImages();
      imageCache!.clear();
      croppedImagePath = filePath;
    });
    Share.shareFiles([filePath], text: 'Great picture');
  }

  Widget _getMainView() {
    if (croppedImagePath != null)
      return Center(
          child: PhotoView(
            imageProvider: FileImage(File(croppedImagePath!)),
          ));
    return ImagePreview(
      imagePath: widget.imagePath,
      edgeDetectionResult: widget.edgeDetectionResult,
    );
  }


  @override
  Widget build(BuildContext context) {
    print('image2');

    return SafeArea(
      child: Scaffold(
        // The image is stored as a file on the device. Use the `Image.file`
        // constructor with the given path to display the image.
        body: _getMainView(),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.check),
          onPressed: () {
            if (croppedImagePath == null) {
              _processImage(widget.imagePath, widget.edgeDetectionResult);
            }
          },
        ),
      ),
    );
  }
}
