import 'package:flutter/material.dart';

import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/presentation/widgets/survey_form_view.dart';

class SurveyPreviewScreen extends StatefulWidget {
  const SurveyPreviewScreen({super.key, required this.name, required this.schema});

  final String name;
  final SurveySchema schema;

  @override
  State<SurveyPreviewScreen> createState() => _SurveyPreviewScreenState();
}

class _SurveyPreviewScreenState extends State<SurveyPreviewScreen> {
  final Map<String, dynamic> _answers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name.trim().isEmpty ? 'Preview' : widget.name)),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Preview only. Answers here are not saved.'),
          ),
          SurveyFormView(
            schema: widget.schema,
            answers: _answers,
            fieldErrors: const {},
            readOnly: false,
            onChanged: (id, value) => setState(() {
              if (value == null) {
                _answers.remove(id);
              } else {
                _answers[id] = value;
              }
            }),
            onAddPhoto: (_) async {},
            onRemovePhoto: (field, fileId) {},
            onSign: (_) async {},
            onCaptureLocation: (_) async {},
            imageBytes: (_) async => null,
          ),
        ],
      ),
    );
  }
}
