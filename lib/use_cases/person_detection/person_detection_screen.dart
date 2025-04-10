import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class PersonDetectionScreen extends StatefulWidget {
  const PersonDetectionScreen({super.key});

  @override
  State<PersonDetectionScreen> createState() => _PersonDetectionScreenState();
}

class _PersonDetectionScreenState extends State<PersonDetectionScreen> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  List<DetectedObject> _detectedObjects = [];

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _videoFile = File(video.path);
          _detectedObjects = [];
        });
        _initializeVideoPlayer();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  void _initializeVideoPlayer() {
    if (_videoFile != null) {
      _videoController = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  Future<void> _processVideo() async {
    if (_videoFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(_videoFile!.path);
      final options = ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      );
      final objectDetector = ObjectDetector(options: options);

      final objects = await objectDetector.processImage(inputImage);

      setState(() {
        _detectedObjects = objects;
        _isProcessing = false;
      });

      objectDetector.close();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Person Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_videoFile != null) ...[
                AspectRatio(
                  aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
                  child: VideoPlayer(_videoController!),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Pick Video'),
              ),
              const SizedBox(height: 16),
              if (_videoFile != null)
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processVideo,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label:
                      Text(_isProcessing ? 'Processing...' : 'Process Video'),
                ),
              if (_detectedObjects.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Detection Results:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  _detectedObjects.length,
                  (index) => Card(
                    child: ListTile(
                      title: Text('Object ${index + 1}'),
                      subtitle: Text(
                        'Confidence: ${(_detectedObjects[index].labels[0].confidence * 100).toStringAsFixed(2)}%',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
