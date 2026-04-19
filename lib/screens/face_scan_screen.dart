import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:chilli/services/biometric_scanner.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';

class FaceScanScreen extends StatefulWidget {
  final VoidCallback onVerified;
  final String? gender;

  const FaceScanScreen({super.key, required this.onVerified, this.gender});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  final BiometricScanner _biometricScanner = BiometricScanner();
  bool _isProcessing = false;
  bool _isVerified = false;
  late String _message;
  List<CameraDescription>? _cameras;
  int _faceDetectedCount = 0;
  static const int _requiredFrames = 5;
  double? _previousBrightness;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_scanController);

    _message = widget.gender != null
        ? "Verifying ${widget.gender} Profile..."
        : "Center your face in the frame";

    _setMaxBrightness();
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setMaxBrightness();
    }
  }

  Future<void> _setMaxBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      }
    } catch (_) {}
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      _cameraController!.startImageStream((image) {
        if (_isProcessing || _isVerified) return;
        _processImage(image);
      });

      setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    _isProcessing = true;
    try {
      final result = await _biometricScanner.scanCameraFrame(
        image,
        _cameraController!.description.sensorOrientation,
      );

      final List<Face> faces = result['faces'];
      final List<ImageLabel> labels = result['labels'];

      if (faces.isNotEmpty) {
        final face = faces.first;
        bool genderMatch = false;

        bool foundMaleIndicator = false;
        bool foundFemaleIndicator = false;

        for (var label in labels) {
          final String text = label.label.toLowerCase();
          final double confidence = label.confidence;

          if (confidence > 0.6) {
            if (text.contains('man') ||
                text.contains('boy') ||
                text.contains('gentleman') ||
                text.contains('male') ||
                text.contains('beard') ||
                text.contains('mustache')) {
              foundMaleIndicator = true;
            }
            if (text.contains('woman') ||
                text.contains('girl') ||
                text.contains('lady') ||
                text.contains('female') ||
                text.contains('lipstick')) {
              foundFemaleIndicator = true;
            }
          }
        }

        final String targetGender = widget.gender?.toLowerCase() ?? 'male';

        if (targetGender == 'male') {
          genderMatch =
              !foundFemaleIndicator ||
              (foundFemaleIndicator && foundMaleIndicator);
        } else {
          if (foundMaleIndicator) {
            genderMatch = false;
          } else {
            final smilingProb = (face.smilingProbability as num?) ?? 0;
            final leftEyeProb = (face.leftEyeOpenProbability as num?) ?? 0;
            final rightEyeProb = (face.rightEyeOpenProbability as num?) ?? 0;

            final cheeksVisible =
                face.landmarks[FaceLandmarkType.leftCheek] != null &&
                face.landmarks[FaceLandmarkType.rightCheek] != null;
            final mouthVisible =
                face.landmarks[FaceLandmarkType.bottomMouth] != null &&
                face.landmarks[FaceLandmarkType.leftMouth] != null &&
                face.landmarks[FaceLandmarkType.rightMouth] != null;
            final noseVisible =
                face.landmarks[FaceLandmarkType.noseBase] != null;

            final hasSmile = smilingProb > 0.35;
            final hasEyesOpen = leftEyeProb > 0.5 && rightEyeProb > 0.5;

            final yawAngle = face.headEulerAngleY ?? 0;
            final yawStable = yawAngle.abs() < 15;

            genderMatch =
                hasSmile &&
                hasEyesOpen &&
                cheeksVisible &&
                mouthVisible &&
                noseVisible &&
                yawStable;
          }
        }

        if (genderMatch) {
          _faceDetectedCount++;
          if (_faceDetectedCount >= _requiredFrames) {
            _onFaceVerified();
          } else {
            if (mounted) {
              setState(() {
                _message =
                    "Verifying ${widget.gender}... (${(_faceDetectedCount * 100 / _requiredFrames).toInt()}%)";
              });
            }
          }
        } else {
          _faceDetectedCount = 0;
          if (mounted) {
            setState(() {
              _message = targetGender == 'female'
                  ? "Identity mismatch. No male traits allowed for female profile."
                  : "Verification failed. Position your face clearly.";
            });
          }
        }
      } else {
        _faceDetectedCount = 0;
        if (mounted) {
          setState(() {
            _message = "No face detected. Center your face.";
          });
        }
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _onFaceVerified() {
    if (mounted) {
      setState(() {
        _isVerified = true;
        _message = "Face Verified Successfully!";
      });
    }

    _cameraController?.stopImageStream();
    _scanController.stop();

    _showToast("Verification successful!", Colors.green);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context);
        widget.onVerified();
      }
    });
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreBrightness();
    _cameraController?.dispose();
    _biometricScanner.release();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          _buildOverlay(context),

          if (!_isVerified)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top:
                      MediaQuery.of(context).size.height * 0.5 -
                      150 +
                      (300 * _scanAnimation.value),
                  left: MediaQuery.of(context).size.width * 0.5 - 125,
                  child: Container(
                    height: 2,
                    width: 250,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF00D2FF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          Positioned(
            top: 45,
            left: 20,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  if (_faceDetectedCount > 0)
                    Container(
                      width: 200,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        value: _faceDetectedCount / _requiredFrames,
                        backgroundColor: const Color(0xFF2D1B5E),
                        color: const Color(0xFF00D2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: _isVerified ? Colors.green : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isVerified)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00D2FF),
                            ),
                          ),
                        if (_isVerified)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isVerified)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.greenAccent,
                  size: 100,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.7),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 300,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
