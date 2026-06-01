import 'package:flutter/material.dart';

import '../models/lead_model.dart';
import '../screens/lead_detail_screen.dart';

class LeadsTable extends StatefulWidget {
  final List<LeadModel> leads;
  final bool showSearch;
  final String emptyMessage;

  const LeadsTable({
    super.key,
    required this.leads,
    this.showSearch = true,
    this.emptyMessage = 'No leads found',
  });

  @override
  State<LeadsTable> createState() => _LeadsTableState();
}

class _LeadsTableState extends State<LeadsTable> {
  static const primaryColor = Color(0xFF5663A0);
  static const headerBg = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  final TextEditingController searchController = TextEditingController();
  String search = '';
  bool openingLead = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<LeadModel> get filteredLeads {
    final q = search.trim().toLowerCase();

    if (q.isEmpty) return widget.leads;

    return widget.leads.where((lead) {
      return lead.fullName.toLowerCase().contains(q) ||
          lead.mobile.toLowerCase().contains(q) ||
          lead.leadCode.toLowerCase().contains(q) ||
          lead.status.toLowerCase().contains(q) ||
          lead.currentDepartment.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> openLead(LeadModel lead) async {
    if (openingLead || !mounted) return;

    setState(() => openingLead = true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadDetailScreen(lead: lead),
      ),
    );

    if (!mounted) return;

    setState(() => openingLead = false);
  }

  @override
  Widget build(BuildContext context) {
    final leads = filteredLeads;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: searchController,
              onChanged: (v) {
                if (!mounted) return;
                setState(() => search = v);
              },
              decoration: InputDecoration(
                hintText: 'Search name, mobile, code, status…',
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE4E1EA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE4E1EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

        Expanded(
          child: leads.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7EAF2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 48,
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 64,
                            headingRowColor: WidgetStateProperty.all(headerBg),
                            headingTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            dataTextStyle: const TextStyle(
                              color: textColor,
                              fontSize: 13,
                            ),
                            columns: const [
                              DataColumn(label: Text('Lead Code')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Mobile')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Department')),
                              DataColumn(label: Text('Priority')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: List.generate(leads.length, (index) {
                              final lead = leads[index];

                              return DataRow(
                                color: WidgetStateProperty.all(
                                  index.isEven
                                      ? Colors.white
                                      : const Color(0xFFF9FAFC),
                                ),
                                cells: [
                                  DataCell(Text(lead.leadCode)),
                                  DataCell(
                                    Text(
                                      lead.fullName.isEmpty
                                          ? '—'
                                          : lead.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(lead.mobile)),
                                  DataCell(statusChip(lead.status)),
                                  DataCell(
                                    Text(
                                      lead.currentDepartment.isEmpty
                                          ? '—'
                                          : lead.currentDepartment,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      lead.priority.isEmpty
                                          ? '—'
                                          : lead.priority,
                                    ),
                                  ),
                                  DataCell(
                                    ElevatedButton(
                                      onPressed: openingLead
                                          ? null
                                          : () => openLead(lead),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text('View'),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: const TextStyle(
          color: primaryColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}