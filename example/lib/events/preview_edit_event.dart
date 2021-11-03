import 'package:opencv/native_library.dart';
enum ImageQuality {
  low,
  medium,
  high,
  original
}

abstract class PreviewEditEvent {}

class DetectEdgeEvent extends PreviewEditEvent {
  final String imagePath;
  DetectEdgeEvent({required this.imagePath});
}

class CropImageEvent extends PreviewEditEvent {
  final String imagePath;
  final EdgeDetectionResult result;
  CropImageEvent({required this.imagePath, required this.result});
}

class CompressImageEvent extends PreviewEditEvent {
  final String imagePath;
  final String quality;
  //final ImageQuality imageQuality;
  CompressImageEvent({required this.imagePath, required this.quality});
}

class ConvertBwEvent extends PreviewEditEvent {
  final String imagePath;
  //final ImageQuality imageQuality;
  ConvertBwEvent({required this.imagePath});
}
