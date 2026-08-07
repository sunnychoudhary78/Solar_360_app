import 'installation_api_service.dart';

class InstallationRepository {
  final InstallationApiService _api;

  InstallationRepository(this._api);

  Future<Map<String, dynamic>?> getByLeadId(String leadId) =>
      _api.getByLeadId(leadId);

  Future<void> createForLead(
    String leadId,
    Map<String, dynamic> body, {
    List<String>? installationImagePaths,
  }) => _api.createForLead(
    leadId,
    body,
    installationImagePaths: installationImagePaths,
  );

  Future<void> update(
    String installationId,
    Map<String, dynamic> body, {
    List<String>? installationImagePaths,
  }) => _api.update(
    installationId,
    body,
    installationImagePaths: installationImagePaths,
  );
}
