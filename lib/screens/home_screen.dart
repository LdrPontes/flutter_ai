import 'package:flutter/material.dart';
import '../use_cases/face_recognition/face_recognition_screen.dart';
import '../use_cases/object_detection/object_detection_screen.dart';
import '../use_cases/person_detection/person_detection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline AI Use Cases'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUseCaseCard(
              context,
              'Face Recognition',
              'Detect and analyze faces in real-time using offline AI',
              Icons.face,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceRecognitionScreen(),
                ),
              ),
            ),
            _buildUseCaseCard(
              context,
              'Bird Detection',
              'Detect and track birds in real-time using object detection',
              Icons.local_drink,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BirdDetectionScreen(),
                ),
              ),
            ),
            _buildUseCaseCard(
              context,
              'Person Detection',
              'Detect people in uploaded videos using offline AI',
              Icons.person,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonDetectionScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUseCaseCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32.0, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
