import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/primary_button.dart';

class CameraScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const CameraScreen({super.key, required this.go});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _cameraInitialized = false;
  String? _cameraError;
  bool _capturing = false;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // 1. Check and request camera permission
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted) {
        print('ERROR [Camera]: Camera permission denied by user.');
        setState(() => _cameraError = 'Camera permission denied. Please enable it in settings.');
        return;
      }
      
      // Request storage permission for saving images
      await Permission.storage.request();

      // 2. Initialize the cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('ERROR [Camera]: No cameras available on device.');
        setState(() => _cameraError = 'No cameras found on this device.');
        return;
      }

      // 3. Initialize camera controller
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
        });
        print('DEBUG [Camera]: Successfully initialized camera feed');
      }
    } catch (e) {
      print('ERROR [Camera]: Failed to initialize camera feed: $e');
      if (mounted) {
        setState(() {
          _cameraError = 'Failed to initialize camera: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _capturing = true);
      
      final image = await _controller!.takePicture();
      
      if (mounted) {
        setState(() {
          _capturedImagePath = image.path;
          _capturing = false;
        });
        print('DEBUG [Camera]: Image captured at ${image.path}');
      }
    } catch (e) {
      print('ERROR [Camera]: Failed to capture image: $e');
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImagePath = null;
    });
  }

  void _savePhoto() {
    // Here you would implement saving to database or storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo saved successfully!')),
    );
    widget.go('farmLogs');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ScreenHeader(title: 'Camera'),
        Expanded(
          child: _cameraError != null
              ? _buildErrorView()
              : _capturedImagePath != null
                  ? _buildCapturedView()
                  : _buildCameraView(),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: FarmoraColors.crit, size: 48),
            const SizedBox(height: 16),
            Text(
              _cameraError!,
              style: const TextStyle(color: FarmoraColors.crit),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Go Back',
              onClick: () => widget.go('home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_cameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Center(
                child: CameraPreview(_controller!),
              ),
              if (_capturing)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: FarmoraColors.surface,
            border: Border(top: BorderSide(color: FarmoraColors.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 32),
                onPressed: () => widget.go('home'),
              ),
              GestureDetector(
                onTap: _capturing ? null : _captureImage,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _capturing ? Colors.grey : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _capturing
                      ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
              ),
              const SizedBox(width: 32), // Spacer for balance
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: _capturedImagePath != null
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 64)
                  : const Icon(Icons.check_circle, color: Colors.green, size: 64),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: FarmoraColors.surface,
            border: Border(top: BorderSide(color: FarmoraColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Retake',
                  onClick: _retakePhoto,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  text: 'Save',
                  onClick: _savePhoto,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
