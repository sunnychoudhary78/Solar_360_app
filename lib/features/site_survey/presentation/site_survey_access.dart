import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/site_survey_config.dart';

class SiteSurveyAccess {
  static bool canOpenTemplates(AuthState auth) {
    if (auth.hasAny(const [
      'survey_template.read',
      'survey_template.create',
      'survey_template.update',
    ])) {
      return true;
    }
    return kSiteSurveyUseLocalStore && auth.isCompanyAdmin;
  }

  static bool canEditTemplates(AuthState auth) {
    if (auth.hasAny(const ['survey_template.create', 'survey_template.update'])) {
      return true;
    }
    return kSiteSurveyUseLocalStore && auth.isCompanyAdmin;
  }

  static bool canReadSurvey(AuthState auth) {
    if (auth.hasPermission('site_survey.read')) return true;
    if (!kSiteSurveyUseLocalStore) return false;
    return auth.isCompanyAdmin ||
        auth.hasPermission('lead.read') ||
        auth.hasPermission('leads.read');
  }

  static bool canFillSurvey(AuthState auth) {
    if (auth.hasPermission('site_survey.create')) return true;
    if (!kSiteSurveyUseLocalStore) return false;
    return canReadSurvey(auth);
  }

  static bool canEditSubmitted(AuthState auth) {
    if (auth.hasPermission('site_survey.update')) return true;
    return kSiteSurveyUseLocalStore && auth.isCompanyAdmin;
  }
}

SurveyActor surveyActor(AuthState auth) {
  return SurveyActor(
    id: auth.profile?.id ?? auth.authUser?.id ?? 'local',
    name: (auth.profile?.name ?? auth.authUser?.name ?? 'You').trim().isEmpty
        ? 'You'
        : (auth.profile?.name ?? auth.authUser?.name ?? 'You'),
    email: auth.profile?.email ?? auth.authUser?.email ?? '',
  );
}
