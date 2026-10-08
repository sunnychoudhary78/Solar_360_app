import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/site_survey/data/site_survey_repository.dart';

final siteSurveyRepositoryProvider = Provider<SiteSurveyRepository>((ref) {
  return SiteSurveyRepository(ref.watch(apiServiceProvider));
});
