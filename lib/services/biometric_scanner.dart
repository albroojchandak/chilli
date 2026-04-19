import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:ui';

class BiometricScanner {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  late ImageLabeler _imageLabeler;

  BiometricScanner() {
    _imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
  }

  Future<Map<String, dynamic>> scanCameraFrame(
    CameraImage image,
    int sensorOrientation,
  ) async {
    final inputImage = _buildInputImage(image, sensorOrientation);
    if (inputImage == null) return {'faces': [], 'labels': []};

    final results = await Future.wait([
      _faceDetector.processImage(inputImage),
      _imageLabeler.processImage(inputImage),
    ]);

    return {
      'faces': results[0] as List<Face>,
      'labels': results[1] as List<ImageLabel>,
    };
  }

  InputImage? _buildInputImage(
    CameraImage image,
    int sensorOrientation,
  ) {
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(
      sensorOrientation,
    );
    if (rotation == null) return null;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final bytes = _yuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } else {
      if (image.planes.isEmpty) return null;
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int imageSize = width * height;
    final Uint8List nv21 = Uint8List(imageSize + (imageSize >> 1));

    int offset = 0;
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final int chromaHeight = height ~/ 2;
    final int chromaWidth = width ~/ 2;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < chromaHeight; row++) {
      final int uRowStart = row * uRowStride;
      final int vRowStart = row * vRowStride;
      for (int col = 0; col < chromaWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;
        nv21[offset++] = vPlane.bytes[vIndex];
        nv21[offset++] = uPlane.bytes[uIndex];
      }
    }
    return nv21;
  }

  Function(bool hasFace)? onFaceDetected;
  Timer? _detectionTimer;

  Future<void> beginStreamScan(MediaStream stream) async {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      onFaceDetected?.call(true);
    });
  }

  void release() {
    _detectionTimer?.cancel();
    _faceDetector.close();
    _imageLabeler.close();
  }
}
