import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opencv/native_library.dart';
import 'package:simple_edge_detection_example/domain/edge_detector.dart';
import 'package:simple_edge_detection_example/domain/image_processor.dart';
import 'package:simple_edge_detection_example/events/preview_edit_event.dart';
import 'package:simple_edge_detection_example/states/preview_edit_state.dart';

class PreviewEditBloc extends Bloc<PreviewEditEvent, PreviewEditState> {

  PreviewEditBloc():super(PreviewEditStateInitial());

  @override
  Stream<PreviewEditState> mapEventToState(PreviewEditEvent previewEditEvent) async* {
    if(previewEditEvent is DetectEdgeEvent) {
      EdgeDetectionResult  result = await EdgeDetector.detectEdgesByImagePath(previewEditEvent.imagePath);
      String resultPath = await _processImage(previewEditEvent.imagePath, result);
      final newState = CropCompleteState(
        imagePath: resultPath,
      );
      yield newState;
    }
    else if(previewEditEvent is CropImageEvent) {
      yield ProcessingState();
      String resultPath = await _processImage(previewEditEvent.imagePath, previewEditEvent.result);
      final newState = CropCompleteState(
        imagePath: resultPath,
      );
      yield newState;
    }
    else if(previewEditEvent is ConvertBwEvent) {
      //yield ProcessingState();
      File file = await _localFile;
      file.createSync();
      await ImageProcessor.convertToBw(previewEditEvent.imagePath, file.path);
      final newState = CompressCompleteState(
        imagePath: file.path,
      );
      yield newState;
    }
    else if(previewEditEvent is CompressImageEvent) {
      int quality = 10;
      switch (previewEditEvent.quality){
        case 'low': quality = 10; break;
        case 'medium': quality = 20; break;
        case 'high': quality = 25; break;
        case 'original': quality = 35; break;
      }
      yield ProcessingState();
      File file = await _localFile;
      file.createSync();
      await ImageProcessor.compressImage(previewEditEvent.imagePath, file.path, 1150, quality);
      imageCache!.clearLiveImages();
      imageCache!.clear();
      final newState = CompressCompleteState(
        imagePath: file.path
      );
      yield newState;
    }
  }

  Future<File> get _localFile async {
    final directory = await getTemporaryDirectory();
    return File('${directory.path}/result.jpg');
  }

  Future<String> _processImage(String filePath, EdgeDetectionResult eresult) async {
    print('edge ${eresult.topLeft}');
    int start = new DateTime.now().millisecondsSinceEpoch;
    bool result = await ImageProcessor.cropImage(filePath, eresult);
    // EdgeDetectionResult cc = EdgeDetectionResult(
    //     topLeft: Offset(0.0, 0.0),
    //     topRight: Offset(0.5,0.0),
    //     bottomLeft: Offset(0.0,1.0),
    //     bottomRight: Offset(0.5,1.0)
    // );
    EdgeDetectionResult cc = EdgeDetectionResult(
        topLeft: Offset(0.5, 0.0),
        topRight: Offset(1.0,0.0),
        bottomLeft: Offset(0.5,1.0),
        bottomRight: Offset(1.0,1.0)
    );
    await ImageProcessor.cropImage(filePath, cc);
    print('crop time ${new DateTime.now().millisecondsSinceEpoch - start} ms');
    print('length cropped ${File(filePath).lengthSync()}');
    imageCache!.clearLiveImages();
    imageCache!.clear();
    return filePath;


    // var image = pw.MemoryImage(
    //   File(filePath).readAsBytesSync(),
    // );
    // widget.pdf.addPage(pw.Page(build: (pw.Context context) {
    //   return pw.Center(
    //     child: pw.Image(image),
    //   ); // Center
    // },margin: pw.EdgeInsets.zero));

    // final file = await _localFile;
    // await file.writeAsBytes(await widget.pdf.save());
    // print('pdf ${file.lengthSync()}');
    // print('pdf ${file.path}');

    //print('length cropped ${file.lengthSync()}');
    //Image image = Image.file(File(filePath));
    //print('size ${image.width}x${image.height}');

  }

}