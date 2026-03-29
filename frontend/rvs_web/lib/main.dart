import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const TabularRVSApp());
}

class TabularRVSApp extends StatelessWidget {
  const TabularRVSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Earthquake Damage RVS',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF101014),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const RVSFormScreen(),
    );
  }
}

class RVSFormScreen extends StatefulWidget {
  const RVSFormScreen({super.key});

  @override
  State<RVSFormScreen> createState() => _RVSFormScreenState();
}

class _RVSFormScreenState extends State<RVSFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _femaTag;
  String? _colorTag;
  int? _damageGrade;
  String? _errorMessage;

  // The 10 Features
  int gl1 = 17, gl2 = 1200, gl3 = 10000;
  int age = 20, families = 1;
  double area = 15.0, height = 10.0;
  String roofType = 'n';
  String foundationType = 'r';
  String position = 's';

  // Replace with your actual FastAPI backend URL (use 10.0.2.2 for Android emulator)
  final String apiUrl = "http://127.0.0.1:8000/analyze";

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _femaTag = null;
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "geo_level_3_id": gl3,
          "geo_level_1_id": gl1,
          "geo_level_2_id": gl2,
          "age": age,
          "area_percentage": area.toInt(),
          "height_percentage": height.toInt(),
          "roof_type": roofType,
          "count_families": families,
          "foundation_type": foundationType,
          "position": position,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          _femaTag = data['fema_tag'];
          _colorTag = data['color'];
          _damageGrade = data['damage_grade'];
        });
      } else {
        setState(() {
          _errorMessage =
              "Server error \${response.statusCode}: \${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to connect to API: \$e";
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

  Widget _buildNumericField(
    String label,
    String hint,
    Function(String?) onSave, {
    int maxLength = 5,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF1E1E26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          counterText: "",
        ),
        validator:
            (value) => value == null || value.isEmpty ? 'Required' : null,
        onSaved: onSave,
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF1E1E26),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
        items:
            items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.toUpperCase()),
                  ),
                )
                .toList(),
        onChanged: onChanged,
        onSaved: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RVS Tool',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181F),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "GEOGRAPHIC REGION",
                        style: TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumericField(
                              "Geo Level 1",
                              "0-30",
                              (val) => gl1 = int.parse(val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildNumericField(
                              "Geo Level 2",
                              "0-1427",
                              (val) => gl2 = int.parse(val!),
                            ),
                          ),
                        ],
                      ),
                      _buildNumericField(
                        "Geo Level 3 ID",
                        "0-12567",
                        (val) => gl3 = int.parse(val!),
                        maxLength: 6,
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Colors.white10),
                      ),

                      const Text(
                        "PHYSICAL DIMENSIONS",
                        style: TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumericField(
                              "Age (Years)",
                              "20",
                              (val) => age = int.parse(val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildNumericField(
                              "Families",
                              "1",
                              (val) => families = int.parse(val!),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Text(
                        "Area Percentage: ${area.toInt()}%",
                        style: const TextStyle(color: Colors.white),
                      ),
                      Slider(
                        value: area,
                        min: 1,
                        max: 100,
                        activeColor: Colors.deepPurple,
                        onChanged: (val) => setState(() => area = val),
                      ),

                      Text(
                        "Height Percentage: ${height.toInt()}%",
                        style: const TextStyle(color: Colors.white),
                      ),
                      Slider(
                        value: height,
                        min: 1,
                        max: 100,
                        activeColor: Colors.deepPurpleAccent,
                        onChanged: (val) => setState(() => height = val),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Colors.white10),
                      ),

                      const Text(
                        "STRUCTURAL MATERIAL",
                        style: TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildDropdownField(
                        "Foundation Type",
                        ['r', 'w', 'i', 'u', 'h'],
                        foundationType,
                        (val) => setState(() => foundationType = val!),
                      ),
                      _buildDropdownField(
                        "Roof Type",
                        ['n', 'q', 'x'],
                        roofType,
                        (val) => setState(() => roofType = val!),
                      ),
                      _buildDropdownField(
                        "Ground Position",
                        ['s', 't', 'j', 'o'],
                        position,
                        (val) => setState(() => position = val!),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.deepPurpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "INITIALIZE PROTOCOL",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
              ),

              const SizedBox(height: 30),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                )
              else if (_femaTag != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_getTagColor().withOpacity(0.3), Colors.black],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getTagColor(), width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "PREDICTED STRUCTURAL INTEGRITY",
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _femaTag!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _getTagColor(),
                          shadows: [
                            Shadow(
                              color: _getTagColor().withOpacity(0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Grade: ${_damageGrade ?? 'N/A'}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
