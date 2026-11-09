
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() =>
      _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _selectedFilter = 'All records';
  String _searchQuery = '';

  final List<String> _filters = [
    'All records',
    'Today',
    'This week',
    'This month',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _getRecordDate(Map<String, dynamic> data) {
    final value = data['visitDate'] ?? data['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _getPatientName(Map<String, dynamic> data) {
    return (data['citizenName'] ??
            data['patientName'] ??
            data['patientFullName'] ??
            'Unknown patient')
        .toString();
  }

  String _getDiagnosis(Map<String, dynamic> data) {
    return (data['diagnosis'] ?? 'Not specified').toString();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;

    return '$day $month $year';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  bool _matchesDateFilter(DateTime? date) {
    if (_selectedFilter == 'All records') return true;
    if (date == null) return false;

    final now = DateTime.now();

    if (_selectedFilter == 'Today') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }

    if (_selectedFilter == 'This week') {
      final startOfWeek =
          DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));

      final startOfNextWeek = startOfWeek.add(
        const Duration(days: 7),
      );

      return !date.isBefore(startOfWeek) &&
          date.isBefore(startOfNextWeek);
    }

    if (_selectedFilter == 'This month') {
      return date.year == now.year &&
          date.month == now.month;
    }

    return true;
  }

  bool _matchesSearch(Map<String, dynamic> data, String documentId) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();

    final searchableFields = [
      _getPatientName(data),
      _getDiagnosis(data),
      data['patientNationalId']?.toString() ?? '',
      data['recordId']?.toString() ?? '',
      data['prescription']?.toString() ?? '',
      data['facilityName']?.toString() ?? '',
      documentId,
    ];

    return searchableFields.any(
      (field) => field.toLowerCase().contains(query),
    );
  }

  void _showRecordDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String documentId,
  ) {
    final patientName = _getPatientName(data);
    final diagnosis = _getDiagnosis(data);
    final date = _getRecordDate(data);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Medical Record Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  _detailSection(
                    'Patient Information',
                    [
                      _detailRow('Patient name', patientName),
                      _detailRow(
                        'National ID',
                        data['patientNationalId']?.toString()
                            ?? 'Not provided',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _detailSection(
                    'Visit Information',
                    [
                      _detailRow('Diagnosis', diagnosis),
                      _detailRow(
                        'Visit date',
                        _formatDate(date),
                      ),
                      _detailRow(
                        'Visit time',
                        _formatTime(date).isEmpty
                            ? 'Not available'
                            : _formatTime(date),
                      ),
                      _detailRow(
                        'Healthcare provider',
                        data['providerName']?.toString()
                            ?? 'Not provided',
                      ),
                      _detailRow(
                        'Facility',
                        data['facilityName']?.toString()
                            ?? 'Not provided',
                      ),
                      _detailRow(
                        'Record ID',
                        data['recordId']?.toString() ??
                            documentId,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _detailSection(
                    'Treatment Information',
                    [
                      _detailRow(
                        'Prescription',
                        data['prescription']?.toString()
                            ?? 'No prescription recorded',
                      ),
                      _detailRow(
                        'Laboratory results',
                        data['labResults']?.toString()
                            ?? 'No laboratory results recorded',
                      ),
                      _detailRow(
                        'Clinical notes',
                        data['notes']?.toString()
                            ?? 'No additional notes',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailSection(
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (user == null) {
      return const Center(
        child: Text('Please log in to view medical records.'),
      );
    }

    final recordsStream = FirebaseFirestore.instance
        .collection('medical_records')
        .where('providerUID', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: recordsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final documents = snapshot.data?.docs ?? [];

            final filteredRecords = documents.where((document) {
              final data = document.data();

              return _matchesDateFilter(_getRecordDate(data)) &&
                  _matchesSearch(data, document.id);
            }).toList();

            filteredRecords.sort((a, b) {
              final dateA = _getRecordDate(a.data());
              final dateB = _getRecordDate(b.data());

              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;

              return dateB.compareTo(dateA);
            });

            final todayCount = documents.where((document) {
              final date = _getRecordDate(document.data());
              if (date == null) return false;

              final now = DateTime.now();

              return date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24, 24, 24, 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medical Records',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'View and manage your patients’ medical records.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 500;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _summaryCard(
                            title: 'Total records',
                            value: documents.length.toString(),
                            icon: Icons.folder_copy_outlined,
                            color: primaryColor,
                            width: isWide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                          ),
                          _summaryCard(
                            title: "Today's visits",
                            value: todayCount.toString(),
                            icon: Icons.today_outlined,
                            color: Colors.teal,
                            width: isWide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search by patient, disease, National ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final selected =
                          _selectedFilter == filter;

                      return ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        selectedColor:
                            primaryColor.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: selected
                              ? primaryColor
                              : theme.colorScheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selected
                              ? primaryColor
                              : theme.dividerColor,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Patient Records',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${filteredRecords.length} found',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: filteredRecords.isEmpty
                      ? _buildEmptyState(
                          documents.isEmpty
                              ? 'No medical records yet'
                              : 'No matching records found',
                          documents.isEmpty
                              ? 'Records created by your account will appear here.'
                              : 'Try another search term or date filter.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            24, 4, 24, 24,
                          ),
                          itemCount: filteredRecords.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final document =
                                filteredRecords[index];
                            final data = document.data();

                            return _recordCard(
                              context: context,
                              data: data,
                              documentId: document.id,
                              primaryColor: primaryColor,
                              onTap: () {
                                _showRecordDetails(
                                  context,
                                  data,
                                  document.id,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String documentId,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final date = _getRecordDate(data);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor:
                    primaryColor.withValues(alpha: 0.10),
                child: Icon(
                  Icons.person_outline,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPatientName(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _getDiagnosis(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.red,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load medical records',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Check your Firebase connection and Firestore security rules.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
