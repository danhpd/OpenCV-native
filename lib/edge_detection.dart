import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class Coordinate extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;

  factory Coordinate.allocate(double x, double y) =>
      malloc<Coordinate>().ref
        ..x = x
        ..y = y;
}

class NativeDetectionResult extends Struct {
  external Pointer<Coordinate> topLeft;
  external Pointer<Coordinate> topRight;
  external Pointer<Coordinate> bottomLeft;
  external Pointer<Coordinate> bottomRight;

  factory NativeDetectionResult.allocate(
      Pointer<Coordinate> topLeft,
      Pointer<Coordinate> topRight,
      Pointer<Coordinate> bottomLeft,
      Pointer<Coordinate> bottomRight) =>
      malloc<NativeDetectionResult>().ref
        ..topLeft = topLeft
        ..topRight = topRight
        ..bottomLeft = bottomLeft
        ..bottomRight = bottomRight;
}

class EdgeDetectionResult {
  EdgeDetectionResult({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  Offset topLeft;
  Offset topRight;
  Offset bottomLeft;
  Offset bottomRight;
}

typedef DetectEdgesFunction = Pointer<NativeDetectionResult> Function(
  Pointer<Utf8> imagePath);

typedef convert_func = Pointer<NativeDetectionResult> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef Convert = Pointer<NativeDetectionResult> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, int, int, int, int);

typedef process_image_function = Int8 Function(
  Pointer<Utf8> imagePath,
  Double topLeftX,
  Double topLeftY,
  Double topRightX,
  Double topRightY,
  Double bottomLeftX,
  Double bottomLeftY,
  Double bottomRightX,
  Double bottomRightY
);

typedef ProcessImageFunction = int Function(
  Pointer<Utf8> imagePath,
  double topLeftX,
  double topLeftY,
  double topRightX,
  double topRightY,
  double bottomLeftX,
  double bottomLeftY,
  double bottomRightX,
  double bottomRightY
);

// https://github.com/dart-lang/samples/blob/master/ffi/structs/structs.dart

class EdgeDetection {
  static Future<EdgeDetectionResult> detectEdges(String path) async {
    DynamicLibrary nativeEdgeDetection = _getDynamicLibrary();

    final detectEdges = nativeEdgeDetection
        .lookup<NativeFunction<DetectEdgesFunction>>("detect_edges")
        .asFunction<DetectEdgesFunction>();

    NativeDetectionResult detectionResult = detectEdges(path.toNativeUtf8()).ref;

    return EdgeDetectionResult(
        topLeft: Offset(
            detectionResult.topLeft.ref.x, detectionResult.topLeft.ref.y
        ),
        topRight: Offset(
            detectionResult.topRight.ref.x, detectionResult.topRight.ref.y
        ),
        bottomLeft: Offset(
            detectionResult.bottomLeft.ref.x, detectionResult.bottomLeft.ref.y
        ),
        bottomRight: Offset(
            detectionResult.bottomRight.ref.x, detectionResult.bottomRight.ref.y
        )
    );
  }

  static Future<EdgeDetectionResult> detectEdges2(CameraImage cameraImage) async {
    Pointer<Uint8> p = calloc(cameraImage.planes[0].bytes.length);
    Pointer<Uint8> p1 = calloc(cameraImage.planes[1].bytes.length);
    Pointer<Uint8> p2 = calloc(cameraImage.planes[2].bytes.length);

    // Assign the planes data to the pointers of the image
    Uint8List pointerList = p.asTypedList(cameraImage.planes[0].bytes.length);
    Uint8List pointerList1 = p1.asTypedList(cameraImage.planes[1].bytes.length);
    Uint8List pointerList2 = p2.asTypedList(cameraImage.planes[2].bytes.length);
    pointerList.setRange(
        0, cameraImage.planes[0].bytes.length, cameraImage.planes[0].bytes);
    pointerList1.setRange(
        0, cameraImage.planes[1].bytes.length, cameraImage.planes[1].bytes);
    pointerList2.setRange(
        0, cameraImage.planes[2].bytes.length, cameraImage.planes[2].bytes);

    DynamicLibrary nativeEdgeDetection = _getDynamicLibrary();

    final detectEdges = nativeEdgeDetection
        .lookup<NativeFunction<convert_func>>("detect_edges2")
        .asFunction<Convert>();

    NativeDetectionResult detectionResult = detectEdges(
        p,p1,p2,
        cameraImage.planes[1].bytesPerRow,
        cameraImage.planes[1].bytesPerPixel!,
        cameraImage.width,
        cameraImage.height).ref;

    calloc.free(p);
    calloc.free(p1);
    calloc.free(p2);

    return EdgeDetectionResult(
        topLeft: Offset(
            detectionResult.topLeft.ref.x, detectionResult.topLeft.ref.y
        ),
        topRight: Offset(
            detectionResult.topRight.ref.x, detectionResult.topRight.ref.y
        ),
        bottomLeft: Offset(
            detectionResult.bottomLeft.ref.x, detectionResult.bottomLeft.ref.y
        ),
        bottomRight: Offset(
            detectionResult.bottomRight.ref.x, detectionResult.bottomRight.ref.y
        )
    );
  }

  static Future<bool> processImage(String path, EdgeDetectionResult result) async {
    DynamicLibrary nativeEdgeDetection = _getDynamicLibrary();

    final processImage = nativeEdgeDetection
        .lookup<NativeFunction<process_image_function>>("process_image")
        .asFunction<ProcessImageFunction>();


    return processImage(
        path.toNativeUtf8(),
        result.topLeft.dx,
        result.topLeft.dy,
        result.topRight.dx,
        result.topRight.dy,
        result.bottomLeft.dx,
        result.bottomLeft.dy,
        result.bottomRight.dx,
        result.bottomRight.dy
    ) == 1;
  }

  static DynamicLibrary _getDynamicLibrary() {
    final DynamicLibrary nativeEdgeDetection = Platform.isAndroid
        ? DynamicLibrary.open("libnative_edge_detection.so")
        : DynamicLibrary.process();
    return nativeEdgeDetection;
  }
}