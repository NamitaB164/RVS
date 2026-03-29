import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const RVSApp());
}

class RVSApp extends StatelessWidget {
  const RVSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RVS Builder Safety',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const RVSScannerScreen(),
    );
  }
}

class RVSScannerScreen extends StatefulWidget {
  const RVSScannerScreen({super.key});

  @override
  State<RVSScannerScreen> createState() => _RVSScannerScreenState();
}

class _RVSScannerScreenState extends State<RVSScannerScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  String? _femaTag;
  String? _colorTag;
  double? _confidence;
  String? _errorMessage;

  // Replace with your FastAPI backend URL (use 10.0.2.2 for Android emulator pointing to localhost)
  final String apiUrl = "http://127.0.0.1:8000/predict"; 

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _femaTag = null;
          _errorMessage = null;
        });
        _analyzeImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error picking image: \$e";
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('file', _imageFile!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          _femaTag = data['fema_tag'];
          _colorTag = data['color'];
          _confidence = data['confidence'];
        });
      } else {
        setState(() {
          _errorMessage = "Server error: \${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to connect to API. Please ensure Backend is running locally or enter correct URL.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getTagColor() {
    if (_colorTag == "green") return Colors.greenAccent;
    if (_colorTag == "yellow") return Colors.orangeAccent;
    if (_colorTag == "red") return Colors.redAccent;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RVS Damage Assessor', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Capture or upload a building image to classify structural safety.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 30),
              
              // Image Viewer Card
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))
                  ]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _imageFile != null
                      ? (kIsWeb ? Image.network(_imageFile!.path, fit: BoxFit.cover) : Image.file(_imageFile!, fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo_outlined, size: 60, color: Colors.white38),
                            SizedBox(height: 16),
                            Text("No image selected", style: TextStyle(color: Colors.white38))
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text("Camera", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      backgroundColor: const Color(0xFF2A2A3D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Loading State & Results
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                )
              else if (_femaTag != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getTagColor().withOpacity(0.2),
                        const Color(0xFF1E1E1E)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getTagColor(), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "FEMA TAG ASSIGNED",
                        style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _femaTag!,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _getTagColor(),
                          shadows: [Shadow(color: _getTagColor().withOpacity(0.5), blurRadius: 20)]
                        ),
                      ),
                      if (_confidence != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          "Confidence: \${(_confidence! * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        )
                      ]
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
