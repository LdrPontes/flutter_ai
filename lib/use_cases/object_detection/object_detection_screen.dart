import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class BirdDetectionScreen extends StatefulWidget {
  const BirdDetectionScreen({super.key});

  @override
  State<BirdDetectionScreen> createState() => _BirdDetectionScreenState();
}

class _BirdDetectionScreenState extends State<BirdDetectionScreen> {
  CameraController? _controller;
  ObjectDetector? _objectDetector;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  List<DetectedObject> _objects = [];
  String _text = '';
  CustomPaint? _customPaint;
  int? _trackedBirdId;
  String _detectedBirdLabel = '';
  double _detectedBirdConfidence = 0.0;
  bool _canProcess = false;
  bool _isBusy = false;
  var _cameraLensDirection = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    _checkAndRequestCameraPermission();
  }

  Future<void> _checkAndRequestCameraPermission() async {
    try {
      if (Platform.isIOS) {
        final status = await Permission.camera.status;
        if (status.isDenied) {
          final result = await Permission.camera.request();
          if (result.isDenied) {
            setState(() {
              _errorMessage =
                  'Camera permission is required for bird detection';
            });
            return;
          }
        }
      }
      await _initializeCamera();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking camera permission: $e';
      });
      debugPrint('Error checking camera permission: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on device';
        });
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.startImageStream((CameraImage image) {
        if (_isProcessing) return;
        _processImage(image);
      });

      setState(() {
        _isCameraInitialized = true;
      });

      // Initialize the detector after camera is ready
      _initializeDetector();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
      });
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initializeDetector() async {
    _objectDetector?.close();
    _objectDetector = null;
    debugPrint('Initializing bird detector');

    try {
      final modelPath = await _getModelPath('birds.tflite');
      debugPrint('Using bird detection model: $modelPath');
      final options = LocalObjectDetectorOptions(
        mode: DetectionMode.stream,
        modelPath: modelPath,
        classifyObjects: true,
        multipleObjects: true,
      );
      _objectDetector = ObjectDetector(options: options);
    } catch (e) {
      debugPrint('Error loading bird detection model: $e');
      setState(() {
        _errorMessage = 'Error loading bird detection model: $e';
      });
    }

    _canProcess = true;
  }

  Future<String> _getModelPath(String assetPath) async {
    final modelDir = await getApplicationSupportDirectory();
    final modelPath = path.join(modelDir.path, assetPath);

    // Create directory if it doesn't exist
    await Directory(path.dirname(modelPath)).create(recursive: true);

    // Check if model file exists
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      // Copy model from assets
      final byteData = await rootBundle.load('assets/ml/$assetPath');
      await modelFile.writeAsBytes(
        byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    }

    return modelPath;
  }

  Future<void> _processImage(CameraImage image) async {
    if (_objectDetector == null) return;
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final objects = await _objectDetector!.processImage(inputImage);

      // Find birds in the detected objects
      DetectedObject? birdObject;
      String birdLabel = '';
      double birdConfidence = 0.0;

      for (final object in objects) {
        for (final label in object.labels) {
          final labelText = label.text.toLowerCase();

          // Check if the label contains bird-related terms
          if (labelText.contains('bird') ||
              labelText.contains('avian') ||
              labelText.contains('species')) {
            if (label.confidence > birdConfidence) {
              birdObject = object;
              birdLabel = label.text;
              birdConfidence = label.confidence;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _objects = objects;

          // Update tracked bird ID and label
          if (birdObject != null) {
            _trackedBirdId = birdObject.trackingId;
            _detectedBirdLabel = birdLabel;
            _detectedBirdConfidence = birdConfidence;
          } else {
            _detectedBirdLabel = '';
            _detectedBirdConfidence = 0.0;
          }

          // Create custom paint for drawing
          if (inputImage.metadata?.size != null) {
            _customPaint = CustomPaint(
              painter: BirdDetectorPainter(
                objects: _objects,
                imageSize: inputImage.metadata!.size,
                trackedBirdId: _trackedBirdId,
                birdLabel: _detectedBirdLabel,
                birdConfidence: _detectedBirdConfidence,
              ),
            );
          }

          // Update text for debugging
          _text = 'Birds found: ${objects.length}\n';
          for (final object in objects) {
            _text +=
                'Bird: trackingId: ${object.trackingId} - ${object.labels.map((e) => '${e.text} (${(e.confidence * 100).toStringAsFixed(1)}%)')}\n';
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _objectDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bird Detection'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _checkAndRequestCameraPermission();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bird Detection'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bird Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.0,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          if (_customPaint != null) _customPaint!,

          // Debug text overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.black54,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _text,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),

          // Detection results
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.black54,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      'Detected ${_objects.length} bird${_objects.length != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (_trackedBirdId != null)
                      Text(
                        'Bird detected: $_detectedBirdLabel (${(_detectedBirdConfidence * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BirdDetectorPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size imageSize;
  final int? trackedBirdId;
  final String birdLabel;
  final double birdConfidence;

  BirdDetectorPainter({
    required this.objects,
    required this.imageSize,
    this.trackedBirdId,
    this.birdLabel = '',
    this.birdConfidence = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint defaultPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.blue;

    final Paint birdPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (final DetectedObject object in objects) {
      final bool isBird = object.trackingId == trackedBirdId;
      final Paint paint = isBird ? birdPaint : defaultPaint;

      // Scale the bounding box to match the screen size
      final Rect scaledRect = _scaleRect(
        object.boundingBox,
        imageSize,
        size,
      );

      canvas.drawRect(
        scaledRect.deflate(5),
        paint,
      );

      // Draw labels for birds
      if (isBird) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: '$birdLabel (${(birdConfidence * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            scaledRect.left,
            scaledRect.top - textPainter.height - 5,
          ),
        );
      }
    }
  }

  // Helper method to scale the bounding box to match the screen size
  Rect _scaleRect(Rect rect, Size imageSize, Size screenSize) {
    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;

    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }

  @override
  bool shouldRepaint(BirdDetectorPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.trackedBirdId != trackedBirdId ||
        oldDelegate.birdLabel != birdLabel ||
        oldDelegate.birdConfidence != birdConfidence;
  }
}
