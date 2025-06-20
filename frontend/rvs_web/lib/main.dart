import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON encoding

void main() {
  runApp(SeismoTrackApp());
}

class SeismoTrackApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeismoTrack Web',
      home: BuildingForm(),
    );
  }
}

class BuildingForm extends StatefulWidget {
  @override
  _BuildingFormState createState() => _BuildingFormState();
}

class _BuildingFormState extends State<BuildingForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers to capture input
  final TextEditingController yearBuiltController = TextEditingController();
  final TextEditingController storiesController = TextEditingController();
  final TextEditingController materialController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  
  final TextEditingController latController = TextEditingController();
  final TextEditingController longController = TextEditingController();
  
  bool softStory = false;
  bool irregularities = false;

  // Function to submit the form
  Future<void> submitData() async {
  final rvsData = {
    "year_built": int.tryParse(yearBuiltController.text) ?? 0,
    "stories": int.tryParse(storiesController.text) ?? 0,
    "building_material": materialController.text,
    "height": int.tryParse(heightController.text) ?? 0,
    "irregularities": irregularities,
    "latitude": double.tryParse(latController.text) ?? 0.0,
    "longitude": double.tryParse(longController.text) ?? 0.0,
    "soft_story": softStory
  };

  final urlSubmit = Uri.parse('http://127.0.0.1:8000/enter_rvs');
  final urlPredict = Uri.parse('http://127.0.0.1:8000/predict_risk');

  try {
    final responseSubmit = await http.post(
      urlSubmit,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(rvsData),
    );

    if (responseSubmit.statusCode == 200) {
      final responsePredict = await http.post(
        urlPredict,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(rvsData),
      );

      if (responsePredict.statusCode == 200) {
        final json = jsonDecode(responsePredict.body);
        final risk = json["predicted_risk"];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prediction: $risk')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prediction failed.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed.')),
      );
    }
  } catch (e) {
    print("Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error occurred: $e')),
    );
  }
}

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SeismoTrack Building Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: yearBuiltController,
                decoration: InputDecoration(labelText: 'Year Built'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: storiesController,
                decoration: InputDecoration(labelText: 'Number of Stories'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: materialController,
                decoration: InputDecoration(labelText: 'Building Material'),
              ),
              TextFormField(
                controller: heightController,
                decoration: InputDecoration(labelText: 'Height (in meters)'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: Text('Irregularities Present?'),
                value: irregularities,
                onChanged: (bool value) {
                  setState(() {
                    irregularities = value;
                  });
                },
              ),
              TextFormField(
                controller: latController,
                decoration: InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: longController,
                decoration: InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: Text('Soft Story Present?'),
                value: softStory,
                onChanged: (bool value) {
                  setState(() {
                    softStory = value;
                  });
                },
              ),
              
              
              
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    submitData();
                  }
                },
                child: Text('Submit Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
