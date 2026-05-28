import 'dart:io';
import 'package:flutter/material.dart';
import 'services/camera_service.dart'; // Make sure this matches your path

void main() {
  runApp(const ScandAidTestApp());
}

class ScandAidTestApp extends StatelessWidget {
  const ScandAidTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const CameraTestScreen(),
    );
  }
}

class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  final CameraService _cameraService = CameraService();
  String? _capturedImagePath;

  Future<void> _testCamera() async {
    // Call the service we just built!
    final String? path = await _cameraService.captureInjuryPhoto();
    
    // Update the UI with the temporary path
    setState(() {
      _capturedImagePath = path;
    });
  }

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(title: const Text('ScandAid Camera Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_capturedImagePath != null) ...[
              const Text('✅ Success! Image captured at cache path:', style: TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                // FIXED: Changed "Center" to "TextAlign.center"
                child: Text(_capturedImagePath!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              ),
              // Display the photo directly from its temporary path
              SizedBox(
                height: 300,
                child: Image.file(File(_capturedImagePath!)),
              ),
            ] else ...[
              const Text('No image captured yet.'),
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _testCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Test Camera Lens'),
            ),
          ],
        ),
      ),
    );
  }
}