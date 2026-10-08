import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';

SurveyField _field({
  required String id,
  required String type,
  required String label,
  bool required = false,
  String? unit,
  List<String> options = const [],
  int? maxPhotos,
  ShowIfRule? showIf,
}) {
  return SurveyField(
    id: id,
    type: type,
    label: label,
    required: required,
    unit: unit,
    options: options,
    maxPhotos: maxPhotos,
    showIf: showIf,
  );
}

SurveySection _visitSection() {
  return SurveySection(
    id: 'site_visit',
    title: 'Site visit',
    fields: [
      _field(id: 'visit_date', type: 'date', label: 'Visit date', required: true),
      _field(id: 'visited_by', type: 'text', label: 'Visited by', required: true),
      _field(id: 'customer_present', type: 'boolean', label: 'Customer present during visit?'),
      _field(id: 'site_location', type: 'location', label: 'Site location'),
    ],
  );
}

SurveySection _recommendationSection() {
  return SurveySection(
    id: 'recommendation',
    title: 'Recommendation',
    fields: [
      _field(
        id: 'recommended_capacity',
        type: 'number',
        label: 'Recommended system capacity',
        required: true,
        unit: 'kW',
      ),
      _field(id: 'remarks', type: 'textarea', label: 'Remarks'),
      _field(
        id: 'customer_signature',
        type: 'signature',
        label: 'Customer signature',
        showIf: const ShowIfRule(field: 'customer_present', op: 'equals', value: true),
      ),
    ],
  );
}

SurveySchema residentialStarterSchema() {
  return SurveySchema(
    sections: [
      _visitSection(),
      SurveySection(
        id: 'roof',
        title: 'Roof',
        fields: [
          _field(
            id: 'roof_type',
            type: 'select',
            label: 'Roof type',
            required: true,
            options: const ['RCC', 'Tin / metal sheet', 'Asbestos', 'Tiled', 'Other'],
          ),
          _field(
            id: 'roof_type_other',
            type: 'text',
            label: 'Describe the roof type',
            required: true,
            showIf: const ShowIfRule(field: 'roof_type', op: 'equals', value: 'Other'),
          ),
          _field(
            id: 'roof_can_bear_load',
            type: 'boolean',
            label: 'Roof can bear panel load?',
            required: true,
          ),
          _field(
            id: 'shadow_free_roof',
            type: 'boolean',
            label: 'Shadow-free roof?',
            required: true,
          ),
          _field(
            id: 'shadow_free_area',
            type: 'number',
            label: 'Shadow-free area',
            required: true,
            unit: 'sq ft',
          ),
          _field(id: 'roof_height', type: 'number', label: 'Roof height from ground', unit: 'ft'),
          _field(id: 'roof_access', type: 'text', label: 'Roof access'),
          _field(
            id: 'roof_photos',
            type: 'photo',
            label: 'Roof photos',
            required: true,
            maxPhotos: 6,
          ),
        ],
      ),
      SurveySection(
        id: 'electrical',
        title: 'Electrical',
        fields: [
          _field(
            id: 'connection_type',
            type: 'select',
            label: 'Connection type',
            required: true,
            options: const ['Single phase', 'Three phase'],
          ),
          _field(id: 'sanctioned_load', type: 'number', label: 'Sanctioned load', unit: 'kW'),
          _field(id: 'meter_location', type: 'text', label: 'Meter location'),
          _field(id: 'meter_photo', type: 'photo', label: 'Meter photo', maxPhotos: 2),
          _field(id: 'earthing_available', type: 'boolean', label: 'Earthing available?'),
          _field(id: 'proposed_inverter_location', type: 'text', label: 'Proposed inverter location'),
        ],
      ),
      _recommendationSection(),
    ],
  );
}

SurveySchema commercialStarterSchema() {
  return SurveySchema(
    sections: [
      _visitSection(),
      SurveySection(
        id: 'building',
        title: 'Building',
        fields: [
          _field(
            id: 'building_type',
            type: 'select',
            label: 'Building type',
            required: true,
            options: const ['Office', 'Retail', 'Warehouse', 'Industrial shed', 'Other'],
          ),
          _field(id: 'number_of_floors', type: 'number', label: 'Number of floors'),
          _field(
            id: 'monthly_bill',
            type: 'number',
            label: 'Average monthly bill',
            required: true,
            unit: '₹',
          ),
          _field(id: 'operating_hours', type: 'text', label: 'Operating hours'),
        ],
      ),
      SurveySection(
        id: 'roof',
        title: 'Roof',
        fields: [
          _field(
            id: 'roof_type',
            type: 'select',
            label: 'Roof type',
            required: true,
            options: const ['RCC', 'Metal sheet', 'Asbestos', 'Ground mount', 'Other'],
          ),
          _field(
            id: 'roof_type_other',
            type: 'text',
            label: 'Describe the roof type',
            required: true,
            showIf: const ShowIfRule(field: 'roof_type', op: 'equals', value: 'Other'),
          ),
          _field(
            id: 'structure_can_bear_load',
            type: 'boolean',
            label: 'Structure can bear panel load?',
            required: true,
          ),
          _field(
            id: 'shadow_free_area',
            type: 'number',
            label: 'Shadow-free area',
            required: true,
            unit: 'sq ft',
          ),
          _field(
            id: 'obstructions',
            type: 'multiselect',
            label: 'Obstructions',
            options: const ['Water tank', 'AC units', 'Parapet', 'Trees', 'Nearby buildings', 'None'],
          ),
          _field(
            id: 'roof_photos',
            type: 'photo',
            label: 'Roof photos',
            required: true,
            maxPhotos: 6,
          ),
        ],
      ),
      SurveySection(
        id: 'electrical',
        title: 'Electrical',
        fields: [
          _field(
            id: 'supply_type',
            type: 'select',
            label: 'Supply type',
            required: true,
            options: const ['LT', 'HT'],
          ),
          _field(
            id: 'connection_type',
            type: 'select',
            label: 'Connection type',
            required: true,
            options: const ['Single phase', 'Three phase'],
          ),
          _field(id: 'sanctioned_load', type: 'number', label: 'Sanctioned load', unit: 'kW'),
          _field(id: 'meter_location', type: 'text', label: 'Meter location'),
          _field(id: 'meter_photo', type: 'photo', label: 'Meter photo', maxPhotos: 2),
          _field(id: 'earthing_available', type: 'boolean', label: 'Earthing available?'),
          _field(id: 'proposed_inverter_location', type: 'text', label: 'Proposed inverter location'),
          _field(id: 'dg_backup', type: 'boolean', label: 'DG backup available?'),
        ],
      ),
      _recommendationSection(),
    ],
  );
}
