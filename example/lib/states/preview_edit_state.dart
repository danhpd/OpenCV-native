import 'package:opencv/native_library.dart';

abstract class PreviewEditState {}

class PreviewEditStateInitial extends PreviewEditState{}

class ProcessingState extends PreviewEditState {}

class EdgeDetectionCompleteState extends PreviewEditState {
  EdgeDetectionResult edgeDetectionResult;
  EdgeDetectionCompleteState({required this.edgeDetectionResult});
}

class CropCompleteState extends PreviewEditState {
  final String imagePath;
  CropCompleteState({required this.imagePath});
}

class CompressCompleteState extends PreviewEditState {
  final String imagePath;
  CompressCompleteState({required this.imagePath});
}

class ConvertBwCompleteState extends PreviewEditState {
  final String imagePath;
  ConvertBwCompleteState({required this.imagePath});
}