import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../home/screens/home_screen.dart';
import '../../leads/models/lead_model.dart';

class LiaisonProcessScreen extends StatefulWidget {
  const LiaisonProcessScreen({super.key});

  @override
  State<LiaisonProcessScreen> createState() =>
      _LiaisonProcessScreenState();
}

class _LiaisonProcessScreenState
    extends State<LiaisonProcessScreen> {
  static const bgColor = Color(0xfff4f7fb);
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  @override
  void initState() {
    super.initState();
    _loadLatestLeads();
  }

  Future<void> _loadLatestLeads() async {
    await HomeScreen.loadLeads();

    if (mounted) {
      setState(() {});
    }
  }

  bool _hasFile(String? path) =>
      path != null && path.trim().isNotEmpty;

  bool _isImage(String path) {
    final p = path.toLowerCase();

    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png');
  }

  bool _isPdf(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  List<String> _docsFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    return raw
        .split('|||')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList();
  }

  List<LeadModel> get liaisonLeads {
    return HomeScreen.leads.where((lead) {
      return lead.status == 'Documents Submitted' ||
          lead.status ==
              'Liaison Process Started' ||
          lead.status ==
              'Bank Coordination In Progress' ||
          lead.status ==
              'Sent For Final Liaison' ||
          lead.status ==
              'Meter Process Started';
    }).toList();
  }

  Future<void> _updateLead(
    LeadModel oldLead,
    LeadModel updatedLead,
  ) async {
    final index =
        HomeScreen.leads.indexOf(oldLead);

    if (index == -1) return;

    setState(() {
      HomeScreen.leads[index] = updatedLead;
    });

    await HomeScreen.saveLeads();
  }

  Future<void> _changeStatus(
    LeadModel lead,
    String status,
  ) async {
    await _updateLead(
      lead,
      lead.copyWith(status: status),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status updated: $status',
        ),
      ),
    );
  }

  Future<void> _openNoteDialog(
    LeadModel lead,
  ) async {
    final controller = TextEditingController(
      text: lead.liaisonNote,
    );

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Add Liaison Note',
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Bank / authority coordination note...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text
                    .trim()
                    .isEmpty) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter note first',
                      ),
                    ),
                  );
                  return;
                }

                await _updateLead(
                  lead,
                  lead.copyWith(
                    liaisonNote:
                        controller.text.trim(),
                    status:
                        'Liaison Completed',
                  ),
                );

                if (!mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Lead sent to Finance Team',
                    ),
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Documents Submitted':
        return Colors.orange;

      case 'Liaison Process Started':
        return Colors.blue;

      case 'Bank Coordination In Progress':
        return Colors.indigo;

      case 'Liaison Completed':
        return Colors.green;

      case 'Sent For Final Liaison':
        return Colors.deepPurple;

      case 'Meter Process Started':
        return Colors.purple;

      case 'Government Approval Completed':
        return Colors.teal;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Liaison Officer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: liaisonLeads.isEmpty
          ? const Center(
              child: Text(
                'No leads received from Support Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            )
          : ListView(
              padding:
                  const EdgeInsets.all(16),
              children: [
                _workflowHeader(),
                const SizedBox(height: 20),
                const Text(
                  'Pending Liaison Work',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                ...liaisonLeads.map(
                  (lead) =>
                      _leadCard(lead),
                ),
              ],
            ),
    );
  }

  Widget _workflowHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff1e3c72),
            Color(0xff2a5298),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: const Text(
        'Sales → Support → Liaison → Finance → Installation → Final Liaison → Closed',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _leadCard(LeadModel lead) {
    final color =
        _statusColor(lead.status);

    return Container(
      margin:
          const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    primaryColor.withOpacity(
                  0.12,
                ),
                child: const Icon(
                  Icons.person,
                  color: primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  lead.name.isEmpty
                      ? 'Customer Lead'
                      : lead.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _infoRow(
            Icons.phone,
            'Mobile',
            lead.mobile,
          ),

          _infoRow(
            Icons.email_outlined,
            'Email',
            lead.email,
          ),

          _infoRow(
            Icons.confirmation_number,
            'CA No',
            lead.caNo,
          ),

          _infoRow(
            Icons.numbers,
            'K No',
            lead.kNo,
          ),

          _infoRow(
            Icons.business,
            'Discom',
            lead.discom,
          ),

          _infoRow(
            Icons.note_alt_outlined,
            'Support Notes',
            lead.supportNotes,
          ),

          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color:
                  color.withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),
            child: Text(
              lead.status,
              style: TextStyle(
                color: color,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 18),

          _documentSection(lead),

          if (lead.liaisonNote
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green
                    .withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child: Text(
                'Liaison Note:\n${lead.liaisonNote}',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          _actionButton(lead),
        ],
      ),
    );
  }

  Widget _actionButton(
    LeadModel lead,
  ) {
    if (lead.status ==
        'Documents Submitted') {
      return _mainButton(
        title:
            'Start Liaison Process',
        icon: Icons.play_arrow_rounded,
        color: Colors.orange,
        onTap: () => _changeStatus(
          lead,
          'Liaison Process Started',
        ),
      );
    }

    if (lead.status ==
        'Liaison Process Started') {
      return _mainButton(
        title:
            'Start Bank Coordination',
        icon:
            Icons.account_balance_rounded,
        color: Colors.blue,
        onTap: () => _changeStatus(
          lead,
          'Bank Coordination In Progress',
        ),
      );
    }

    if (lead.status ==
        'Bank Coordination In Progress') {
      return _mainButton(
        title:
            'Add Note & Submit To Finance',
        icon: Icons.note_add_rounded,
        color: Colors.green,
        onTap: () =>
            _openNoteDialog(lead),
      );
    }

    if (lead.status ==
        'Sent For Final Liaison') {
      return _mainButton(
        title: 'Start Meter Process',
        icon:
            Icons.electric_meter_rounded,
        color: Colors.deepPurple,
        onTap: () => _changeStatus(
          lead,
          'Meter Process Started',
        ),
      );
    }

    if (lead.status ==
        'Meter Process Started') {
      return _mainButton(
        title:
            'Complete Government Approval',
        icon: Icons.verified_rounded,
        color: Colors.teal,
        onTap: () => _changeStatus(
          lead,
          'Government Approval Completed',
        ),
      );
    }

    return const SizedBox();
  }

  Widget _mainButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _documentSection(
    LeadModel lead,
  ) {
    final supportDocs =
        _docsFromString(
      lead.supportDocumentPath,
    );

    final customerDocs =
        _docsFromString(
      lead.customerDocuments,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        _fileTile(
          'Aadhaar Front',
          lead.aadhaarFrontPath,
        ),

        _fileTile(
          'Aadhaar Back',
          lead.aadhaarBackPath,
        ),

        _fileTile(
          'PAN Front',
          lead.panFrontPath,
        ),

        _fileTile(
          'PAN Back',
          lead.panBackPath,
        ),

        _fileTile(
          'Electricity Bill',
          lead.electricityBillPath,
        ),

        _fileTile(
          'Bank Document',
          lead.bankImagePath,
        ),

        _fileTile(
          'Roof Document',
          lead.roofImagePath,
        ),

        ...customerDocs.asMap().entries.map(
          (entry) {
            return _fileTile(
              'Checklist Doc ${entry.key + 1}',
              entry.value,
            );
          },
        ),

        ...supportDocs.asMap().entries.map(
          (entry) {
            return _fileTile(
              'Support Doc ${entry.key + 1}',
              entry.value,
            );
          },
        ),
      ],
    );
  }

  Widget _fileTile(
    String title,
    String? path,
  ) {
    if (!_hasFile(path)) {
      return const SizedBox();
    }

    final filePath = path!;

    final isImage =
        _isImage(filePath);

    final isPdf = _isPdf(filePath);

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            primaryColor.withOpacity(
          0.07,
        ),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () {
          if (isImage) {
            _openImage(filePath);
          } else {
            OpenFilex.open(filePath);
          }
        },
        leading: Icon(
          isPdf
              ? Icons.picture_as_pdf
              : isImage
                  ? Icons.image
                  : Icons.insert_drive_file,
          color:
              isPdf ? Colors.red : primaryColor,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Text(
          filePath.split('/').last,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.open_in_new,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(
    String imagePath,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets.all(14),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      errorBuilder:
                          (
                            context,
                            error,
                            stackTrace,
                          ) {
                        return Container(
                          height: 260,
                          alignment:
                              Alignment.center,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              18,
                            ),
                          ),
                          child: const Text(
                            'Image not found',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor:
                      Colors.white,
                  child: IconButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}