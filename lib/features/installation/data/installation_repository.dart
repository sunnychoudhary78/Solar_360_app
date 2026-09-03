import 'installation_api_service.dart';

class InstallationRepository {
  final InstallationApiService _api;

  InstallationRepository(this._api);

  Future<Map<String, dynamic>?> getByLeadId(String leadId) =>
      _api.getByLeadId(leadId);

  Future<Map<String, dynamic>?> getForm(String leadId) => _api.getForm(leadId);

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

  /// Create when no row exists yet; update when it does.
  ///
  /// Material Engineer first-fill often has no installation row. If the UI
  /// accidentally holds the lead id, PUT /installations/:id 404s with
  /// "Installation details not found" — fall back to create in that case.
  Future<void> saveForLead({
    required String leadId,
    String? installationId,
    required Map<String, dynamic> body,
    List<String>? installationImagePaths,
  }) async {
    final id = (installationId ?? '').trim();
    final canUpdate = id.isNotEmpty && id != leadId.trim();

    if (canUpdate) {
      try {
        await update(
          id,
          body,
          installationImagePaths: installationImagePaths,
        );
        return;
      } catch (e) {
        if (!_isMissingInstallation(e)) rethrow;
      }
    }

    try {
      await createForLead(
        leadId,
        body,
        installationImagePaths: installationImagePaths,
      );
    } catch (e) {
      if (!_isAlreadyExists(e)) rethrow;
      final existing = await getByLeadId(leadId);
      final existingId = existing?['id']?.toString().trim() ?? '';
      if (existingId.isEmpty) rethrow;
      await update(
        existingId,
        body,
        installationImagePaths: installationImagePaths,
      );
    }
  }

  bool _isMissingInstallation(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('not found') || message.contains('404');
  }

  bool _isAlreadyExists(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('already exist');
  }
}
