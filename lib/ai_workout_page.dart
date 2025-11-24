import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';
import 'services/pose_utils.dart';
import 'app_theme.dart';

class AiWorkoutPage extends StatefulWidget {
  final String exerciseName;
  const AiWorkoutPage({super.key, required this.exerciseName});

  @override
  State<AiWorkoutPage> createState() => _AiWorkoutPageState();
}

// ДОБАВЛЕНО: with WidgetsBindingObserver
class _AiWorkoutPageState extends State<AiWorkoutPage> with WidgetsBindingObserver {
  CameraController? _controller;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isProcessing = false;

  int _counter = 0;
  String _feedback = "Встаньте перед камерой";
  bool _wasDown = false;
  bool _showSuccessFlash = false;
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Подписываемся на события
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Отписываемся
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  // ДОБАВЛЕНО: Обработка жизненного цикла
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // Если контроллер еще не создан или не инициализирован
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Приложение сворачивается: освобождаем ресурсы
      cameraController.dispose();
      if(mounted) {
        setState(() {
          _controller = null;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // Приложение разворачивается: инициализируем заново
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      _controller!.startImageStream(_processImage);
      setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final landmarks = poses.first.landmarks.values.toList();
        final result = PoseUtils.checkSquat(landmarks);

        if (mounted) {
          setState(() {
            _statusColor = result.isGoodPose ? Colors.white : AppColors.red;
            if (result.feedback.isNotEmpty) _feedback = result.feedback;

            if (result.isRep) {
              _wasDown = true;
            }
            else if (_feedback == "Встаньте прямо" && _wasDown) {
              _counter++;
              _wasDown = false;
              _feedback = "ЕСТЬ! (${_counter})";
              _triggerSuccessEffect();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _triggerSuccessEffect() {
    setState(() => _showSuccessFlash = true);
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showSuccessFlash = false);
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final rotationCompensation = (sensorOrientation + orientations[DeviceOrientation.portraitUp]!) % 360;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation0deg,
        format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (var plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: _showSuccessFlash
                  ? AppColors.green.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          Positioned(
            top: 50, left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 60, left: 0, right: 0,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    "$_counter",
                    key: ValueKey<int>(_counter),
                    style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900),
                  ),
                ),
                Text("ПРИСЕДАНИЯ",
                    style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _feedback,
                key: ValueKey<String>(_feedback),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusColor.withOpacity(0.9),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  shadows: [const Shadow(blurRadius: 15, color: Colors.black)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}