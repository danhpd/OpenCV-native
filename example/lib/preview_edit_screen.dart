import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_edge_detection_example/blocs/preview_edit_bloc.dart';
import 'package:simple_edge_detection_example/events/preview_edit_event.dart';
import 'package:simple_edge_detection_example/scan_screen.dart';
import 'package:simple_edge_detection_example/states/preview_edit_state.dart';
import 'edge_detection_shape/cropping_preview.dart';
import 'package:pdf/widgets.dart' as pw;

class PreviewEditScreen extends StatefulWidget {
  final String imagePath;
  String? targetPath;
  final pdf;
  Count count;

  PreviewEditScreen({Key? key, required this.imagePath, this.pdf, required this.count})
      : super(key: key);

  @override
  PreviewEditScreenState createState() => PreviewEditScreenState();
}

class PreviewEditScreenState extends State<PreviewEditScreen> {
  @override
  void initState() {
    super.initState();
    widget.targetPath = widget.imagePath;
    BlocProvider.of<PreviewEditBloc>(context)
        .add(DetectEdgeEvent(imagePath: widget.imagePath));
    // var image = pw.MemoryImage(
    //   File(widget.imagePath).readAsBytesSync(),
    // );
    // pdf.addPage(pw.Page(build: (pw.Context context) {
    //   return pw.Center(
    //
    //     child: pw.Image(image, fit: pw.BoxFit.contain),
    //   ); // Center
    // }));
  }

  Future<File> get _localFile async {
    final directory = await getTemporaryDirectory();
    return File('${directory.path}/counter.pdf');
  }

  Widget _getAppBar() {
    String dropdownValue = 'medium';
    return Container(
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
                onPressed: () {}, child: Icon(Icons.chevron_left)),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: dropdownValue,
              icon: const Icon(Icons.keyboard_arrow_down_sharp),
              iconSize: 24,
              elevation: 16,
              dropdownColor: Colors.blue,
              style: const TextStyle(color: Colors.white, ),
              isExpanded: true,
              underline: Container(
                height: 2,
                color: Colors.white10,
              ),
              onChanged: (String? newValue) {
                setState(() {
                  dropdownValue = newValue!;
                  BlocProvider.of<PreviewEditBloc>(context).add(
                      CompressImageEvent(
                        quality: dropdownValue,
                        imagePath: widget.imagePath,
                      )
                  );
                });
              },
              items: <String>['low', 'medium', 'high', 'original']
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
            child: ElevatedButton(
                onPressed: () {}, child: Icon(Icons.rotate_right)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
                onPressed: () {
                  BlocProvider.of<PreviewEditBloc>(context)
                      .add(ConvertBwEvent(imagePath: widget.imagePath));
                }, child: Icon(Icons.invert_colors)),
          ),
        ],
      ),
    );
  }

  Future<void> saveFile(String filePath) async {
    var image = pw.MemoryImage(
      File(filePath).readAsBytesSync(),
    );
    widget.pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Center(
        child: pw.Image(image),
      ); // Center
    },margin: pw.EdgeInsets.zero));
    widget.count.count = widget.count.count +1;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("${widget.count.count} - ${File(filePath).lengthSync()/1024}kb"),
    ));

  }

  Widget _getMainView() {
    return BlocBuilder<PreviewEditBloc, PreviewEditState>(
      builder: (context, state) {
        if (state is CropCompleteState) {
          print('path ${state.imagePath}');
          print('length cropped ${File(state.imagePath).lengthSync()}');
          widget.targetPath = state.imagePath;
          return PhotoView(
            imageProvider: FileImage(File(state.imagePath)),
          );
        }
        else if (state is CompressCompleteState) {
          print('path ${state.imagePath}');
          print('length cropped ${File(state.imagePath).lengthSync()}');
          widget.targetPath = state.imagePath;
          return PhotoView(
            imageProvider: FileImage(File(state.imagePath)),
          );
        }
        else if (state is EdgeDetectionCompleteState) {
          return ImagePreview(
            imagePath: widget.imagePath,
            edgeDetectionResult: state.edgeDetectionResult,
          );
        }
        return Stack(children: [
          Center(child: Image(image: FileImage(File(widget.imagePath)))),
          Center(child: CircularProgressIndicator(color: Colors.white)),
        ]);
      },
    );
  }

  Widget _getBottomBar() {
    return Container(
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(onPressed: () {}, child: Icon(Icons.image)),
          ElevatedButton(
              onPressed: () {
                // PreviewEditState _state =
                //     BlocProvider.of<PreviewEditBloc>(context).state;
                // if (_state is EdgeDetectionCompleteState) {
                //   BlocProvider.of<PreviewEditBloc>(context).add(
                //       CropImageEvent(
                //           imagePath: widget.imagePath,
                //           result: _state.edgeDetectionResult));
                // }
                saveFile(widget.targetPath!);
                Navigator.pop(context);

              },
              child: Icon(Icons.add_circle)
          ),
          ElevatedButton(
              onPressed: () async {
                final file = await _localFile;
                await file.writeAsBytes(await widget.pdf.save());
                print('pdf ${file.lengthSync()}');
                print('pdf ${file.path}');
                Share.shareFiles([widget.targetPath!], text: 'Great picture');
              },
              child: Icon(Icons.share)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            _getAppBar(),
            Expanded(child: _getMainView()),
            _getBottomBar(),
          ],
        ),
      ),
    );
  }
}
