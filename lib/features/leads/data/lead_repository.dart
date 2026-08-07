import 'models/lead_model.dart';
import 'lead_api_service.dart';

class LeadRepository {
  final LeadApiService _api;

  LeadRepository(this._api);

  Future<void> createLead(
    Map<String, dynamic> data, {
    Map<String, String>? singleFilePaths,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) => _api.createLead(
    data,
    singleFilePaths: singleFilePaths,
    additionalImageEntries: additionalImageEntries,
    additionalDocumentEntries: additionalDocumentEntries,
  );

  Future<void> uploadLeadDocuments({
    required String leadId,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) => _api.uploadLeadDocuments(
    leadId: leadId,
    additionalImageEntries: additionalImageEntries,
    additionalDocumentEntries: additionalDocumentEntries,
  );

  Future<List<LeadModel>> getAllLeads() => _api.getAllLeads();

  Future<LeadModel> getLeadById(String id) => _api.getLeadById(id);

  Future<List<Map<String, dynamic>>> getLeadHistory(String leadId) =>
      _api.getLeadHistory(leadId);

  Future<Map<String, dynamic>> updateLeadStatus({
    required String leadId,
    required String status,
    String? remarks,
  }) => _api.updateLeadStatus(leadId: leadId, status: status, remarks: remarks);

  Future<LeadModel> assignLead(String leadId, Map<String, dynamic> data) =>
      _api.assignLead(leadId, data);

  Future<List<Map<String, dynamic>>> getUsersByRole(List<String> roles) =>
      _api.getUsersByRole(roles);

  Future<void> updateLeadWithFiles(
    String leadId,
    Map<String, dynamic> data, {
    Map<String, String>? singleFilePaths,
    List<String>? registrationImagePaths,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) => _api.updateLeadWithFiles(
    leadId,
    data,
    singleFilePaths: singleFilePaths,
    registrationImagePaths: registrationImagePaths,
    additionalImageEntries: additionalImageEntries,
    additionalDocumentEntries: additionalDocumentEntries,
  );

  Future<LeadModel?> updateLead(String leadId, Map<String, dynamic> data) =>
      _api.updateLead(leadId, data);

  Future<Map<String, dynamic>> getWorkflowMeta() => _api.getWorkflowMeta();
}
