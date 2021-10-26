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

typedef DetectEdgesImagePath = Pointer<NativeDetectionResult> Function(
  Pointer<Utf8> imagePath);

typedef detect_edges_camera_function = Pointer<NativeDetectionResult> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef DetectEdgeCameraFunction = Pointer<NativeDetectionResult> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, int, int, int, int);

typedef convert_to_bw_function = Int8 Function(
    Pointer<Utf8> imagePath,
    Pointer<Utf8> destPath,
    );

typedef ConvertToBwFunction = int Function(
    Pointer<Utf8> imagePath,
    Pointer<Utf8> destPath,
    );

typedef compress_function = Int8 Function(
    Pointer<Utf8> sourPath,
    Pointer<Utf8> destPath,
    Int8 maxWith,
    Int8 quality,
    Int8 threshold
    );

typedef CompressFunction = int Function(
    Pointer<Utf8> sourPath,
    Pointer<Utf8> destPath,
    int maxWith,
    int quality,
    int threshold
    );

typedef crop_image_function = Int8 Function(
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

typedef CropImageFunction = int Function(
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

class NativeLibrary {
  static DynamicLibrary nativeLibrary = Platform.isAndroid
      ? DynamicLibrary.open("libnative_edge_detection.so")
      : DynamicLibrary.process();

  static Future<EdgeDetectionResult> detectEdgesByImagePath(String path) async {
    final detectEdges = nativeLibrary
        .lookup<NativeFunction<DetectEdgesImagePath>>("detect_edges_by_image_path")
        .asFunction<DetectEdgesImagePath>();

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

  static Future<EdgeDetectionResult> detectEdgesByCameraImage(CameraImage cameraImage) async {
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

    final detectEdges = nativeLibrary
        .lookup<NativeFunction<detect_edges_camera_function>>("detect_edges_by_camera_image")
        .asFunction<DetectEdgeCameraFunction>();

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

  static Future<bool> cropImage(String path, EdgeDetectionResult result) async {
    final processImage = nativeLibrary
        .lookup<NativeFunction<crop_image_function>>("crop_image")
        .asFunction<CropImageFunction>();

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

  static Future<bool> convertToBW(String sourPath, String destPath) async {
    final processImage = nativeLibrary
        .lookup<NativeFunction<convert_to_bw_function>>("convert_to_bw")
        .asFunction<ConvertToBwFunction>();
    return processImage(
        sourPath.toNativeUtf8(),
        destPath.toNativeUtf8(),
    ) == 1;
  }

  static Future<bool> compressImage(String sourPath, String destPath, int maxWidth, int quality, int threshold) async {
    final processImage = nativeLibrary
        .lookup<NativeFunction<compress_function>>("compress_image")
        .asFunction<CompressFunction>();
    return processImage(
        sourPath.toNativeUtf8(),
        destPath.toNativeUtf8(),
        maxWidth,
        quality,
        threshold
    ) == 1;
  }

}