import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_uploader.dart';

class AdminUploaderScreen extends StatefulWidget {
  const AdminUploaderScreen({super.key});

  @override
  State<AdminUploaderScreen> createState() => _AdminUploaderScreenState();
}

class _AdminUploaderScreenState extends State<AdminUploaderScreen> {
  final _uploader = AdminImageUploader();
  final _sceneController = TextEditingController();
  final _tagsController = TextEditingController();
  final _emotionController = TextEditingController();
  final _weatherController = TextEditingController();
  final _timeController = TextEditingController();
  final _activityController = TextEditingController();

  String? _selectedImagePath;
  bool _isUploading = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _sceneController.dispose();
    _tagsController.dispose();
    _emotionController.dispose();
    _weatherController.dispose();
    _timeController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await _picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      setState(() => _selectedImagePath = result.path);
    }
  }

  Future<void> _upload() async {
    if (_selectedImagePath == null || _sceneController.text.isEmpty) return;

    setState(() => _isUploading = true);

    await _uploader.uploadImage(
      filePath: _selectedImagePath!,
      scene: _sceneController.text.trim().toLowerCase(),
      tags: _tagsController.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList(),
      emotion: _emotionController.text.trim().toLowerCase().nullIfEmpty,
      weather: _weatherController.text.trim().toLowerCase().nullIfEmpty,
      time: _timeController.text.trim().toLowerCase().nullIfEmpty,
      activity: _activityController.text.trim().toLowerCase().nullIfEmpty,
    );

    setState(() {
      _isUploading = false;
      _selectedImagePath = null;
      _sceneController.clear();
      _tagsController.clear();
      _emotionController.clear();
      _weatherController.clear();
      _timeController.clear();
      _activityController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Upload Scene Image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview / picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48),
                          SizedBox(height: 8),
                          Text('Tap to select image'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sceneController,
              decoration: const InputDecoration(
                labelText: 'Scene *',
                hintText: 'e.g. bedroom, cafe, beach',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                hintText: 'warm, cozy, window, rain',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emotionController,
              decoration: const InputDecoration(
                labelText: 'Emotion',
                hintText: 'romantic, happy, emotional',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weatherController,
              decoration: const InputDecoration(
                labelText: 'Weather',
                hintText: 'sunny, rainy, cloudy, snowy',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Time',
                hintText: 'morning, afternoon, evening, night',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _activityController,
              decoration: const InputDecoration(
                labelText: 'Activity',
                hintText: 'walking, cooking, reading',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading || _selectedImagePath == null
                  ? null
                  : _upload,
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload Image'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _StringExt on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

