import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/colors.dart';

class NewMedicalRecordScreen extends StatefulWidget {
  final String providerName;
  final String? facilityId;

  const NewMedicalRecordScreen({
    super.key,
    required this.providerName,
    this.facilityId,
  });

  @override
  State<NewMedicalRecordScreen> createState() => _NewMedicalRecordScreenState();
}

class _NewMedicalRecordScreenState extends State<NewMedicalRecordScreen> {
  final formKey = GlobalKey<FormState>();

  final nationalIdController = TextEditingController();
  final patientNameController = TextEditingController();
  final ageController = TextEditingController();
  final diagnosisController = TextEditingController();
  final prescriptionController = TextEditingController();
  final labResultsController = TextEditingController();
  final notesController = TextEditingController();

  String? patientUID;

  // Stores the ID of the newly generated medical record.
  String? generatedRecordId;

  String doctorName = '';
  String facilityCode = '';
  String facilityName = '';

  bool isLoadingProfile = true;
  bool isLookingUpPatient = false;
  bool isPatientVerified = false;
  bool isSaving = false;

  DateTime visitDate = DateTime.now();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    loadProviderDetails();
  }

  @override
  void dispose() {
    nationalIdController.dispose();
    patientNameController.dispose();
    ageController.dispose();
    diagnosisController.dispose();
    prescriptionController.dispose();
    labResultsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // LOAD DOCTOR AND FACILITY DETAILS
  // ---------------------------------------------------------

  Future<void> loadProviderDetails() async {
    try {
      final provider = FirebaseAuth.instance.currentUser;

      if (provider == null) {
        throw Exception('No authenticated provider found.');
      }

      final providerDoc = await firestore
          .collection('users')
          .doc(provider.uid)
          .get();

      if (!providerDoc.exists) {
        throw Exception('Provider profile was not found.');
      }

      final providerData = providerDoc.data()!;

      if (providerData['role'] != 'provider' ||
          providerData['status'] != 'active') {
        throw Exception('Your provider account is not active.');
      }

      final fetchedDoctorName = (providerData['fullName'] ?? '')
          .toString()
          .trim();

      final fetchedFacilityCode = (providerData['facility'] ?? '')
          .toString()
          .trim();

      if (fetchedDoctorName.isEmpty) {
        throw Exception('Doctor name is missing from your profile.');
      }

      if (fetchedFacilityCode.isEmpty) {
        throw Exception('Facility information is missing from your profile.');
      }

      final facilityDoc = await firestore
          .collection('facility')
          .doc(fetchedFacilityCode)
          .get();

      String fetchedFacilityName = fetchedFacilityCode;

      if (facilityDoc.exists) {
        final data = facilityDoc.data()!;

        fetchedFacilityName =
            (data['name'] ??
                    data['facilityName'] ??
                    data['hospitalName'] ??
                    data['displayName'] ??
                    fetchedFacilityCode)
                .toString()
                .trim();
      }

      if (!mounted) return;

      setState(() {
        doctorName = fetchedDoctorName;
        facilityCode = fetchedFacilityCode;
        facilityName = fetchedFacilityName;
        isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoadingProfile = false);

      await showMessage('Unable to Load Provider Details', e.toString());
    }
  }

  // ---------------------------------------------------------
  // PATIENT LOOKUP USING NATIONAL ID
  // ---------------------------------------------------------

  Future<void> lookupPatient() async {
    final nationalId = nationalIdController.text.trim();

    if (nationalId.isEmpty) {
      await showMessage(
        'National ID Required',
        'Please enter the patient National ID.',
      );
      return;
    }

    setState(() {
      isLookingUpPatient = true;
      isPatientVerified = false;
      patientUID = null;
      patientNameController.clear();
    });

    try {
      final result = await firestore
          .collection('users')
          .where('nationalId', isEqualTo: nationalId)
          .limit(2)
          .get();

      if (result.docs.isEmpty) {
        throw Exception(
          'No registered patient was found with this National ID.',
        );
      }

      if (result.docs.length > 1) {
        throw Exception(
          'Multiple accounts have this National ID. '
          'Please contact the system administrator.',
        );
      }

      final patientDoc = result.docs.first;
      final patientData = patientDoc.data();

      if (patientData['role'] != 'citizen' ||
          patientData['status'] != 'active') {
        throw Exception('This account is not an active registered patient.');
      }

      final fullName = (patientData['fullName'] ?? '').toString().trim();

      if (fullName.isEmpty) {
        throw Exception('Patient name is missing from their profile.');
      }

      if (!mounted) return;

      setState(() {
        patientUID = patientDoc.id;
        patientNameController.text = fullName;
        isPatientVerified = true;
      });

      await showMessage(
        'Patient Verified',
        'Patient successfully identified:\n\n$fullName',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;

      await showMessage('Patient Lookup Failed', e.toString());
    } finally {
      if (mounted) {
        setState(() => isLookingUpPatient = false);
      }
    }
  }

  // ---------------------------------------------------------
  // MESSAGE DIALOG
  // ---------------------------------------------------------

  Future<void> showMessage(
    String title,
    String message, {
    bool isError = true,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? AppColors.error : AppColors.success,
          size: 45,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // SAVE MEDICAL RECORD
  // ---------------------------------------------------------

  Future<void> saveRecord() async {
    if (!formKey.currentState!.validate()) return;

    if (!isPatientVerified || patientUID == null) {
      await showMessage(
        'Patient Not Verified',
        "Please enter the patient's National ID and verify "
            'their identity before saving the record.',
      );
      return;
    }

    if (doctorName.isEmpty || facilityCode.isEmpty) {
      await showMessage(
        'Provider Details Missing',
        'Doctor and facility information could not be loaded.',
      );
      return;
    }

    final provider = FirebaseAuth.instance.currentUser;

    if (provider == null) {
      await showMessage('Session Expired', 'Please sign in again.');
      return;
    }

    setState(() {
      isSaving = true;
      generatedRecordId = null;
    });

    try {
      final age = int.tryParse(ageController.text.trim());

      if (age == null || age < 0 || age > 150) {
        throw Exception('Please enter a valid patient age.');
      }

      final recordRef = firestore.collection('medical_records').doc();

      final recordId = recordRef.id;

      final record = <String, dynamic>{
        'recordId': recordId,

        // Patient details
        'patientUID': patientUID,
        'patientNationalId': nationalIdController.text.trim(),
        'citizenName': patientNameController.text.trim(),
        'patientAgeAtVisit': age,

        // Provider details
        'providerUID': provider.uid,
        'providerName': doctorName,

        // Facility details
        'facilityId': facilityCode,
        'facilityName': facilityName,

        // Clinical information
        'diagnosis': diagnosisController.text.trim(),
        'prescription': prescriptionController.text.trim(),
        'labResults': labResultsController.text.trim(),
        'notes': notesController.text.trim(),

        // Visit information
        'visitDate': Timestamp.fromDate(visitDate),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save the medical record to Firestore.
      await recordRef.set(record);

      if (!mounted) return;

      // Store the record ID for the QR code panel.
      setState(() {
        generatedRecordId = recordId;
      });

      // Show success message before displaying the QR code.
      await showMessage(
        'Record Successfully Submitted',
        'The medical record has been successfully saved '
            'to the MDHP database.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;

      await showMessage('Unable to Save Record', e.toString());
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  // ---------------------------------------------------------
  // QR CODE DISPLAY PANEL
  // ---------------------------------------------------------

  Widget qrCodePanel() {
    if (generatedRecordId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24, bottom: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 38),

          const SizedBox(height: 10),

          const Text(
            'Medical Record QR Code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Scan this QR code with the MDHP app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: generatedRecordId!,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'UNIQUE MEDICAL RECORD ID',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 8),

          SelectableText(
            generatedRecordId!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: generatedRecordId!));

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Record ID copied successfully.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Record ID'),
          ),

          const SizedBox(height: 10),

          const Text(
            'This QR code contains only the medical record '
            'identifier. Patient information remains stored '
            'in the database.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // CLEAR FORM
  // ---------------------------------------------------------

  void clearForm() {
    formKey.currentState?.reset();

    nationalIdController.clear();
    patientNameController.clear();
    ageController.clear();
    diagnosisController.clear();
    prescriptionController.clear();
    labResultsController.clear();
    notesController.clear();

    setState(() {
      patientUID = null;
      generatedRecordId = null;
      isPatientVerified = false;
      visitDate = DateTime.now();
    });
  }

  // ---------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // INPUT FIELD
  // ---------------------------------------------------------

  Widget inputField(
    String label,
    TextEditingController controller, {
    String? hint,
    int? maxLines = 1,
    int? minLines,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? customValidator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: keyboardType,
            textAlignVertical: TextAlignVertical.top,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint ?? 'Enter $label',
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator:
                customValidator ??
                (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }

                  if (keyboardType == TextInputType.number) {
                    final age = int.tryParse(value.trim());

                    if (age == null || age < 0 || age > 150) {
                      return 'Enter a valid age';
                    }
                  }

                  return null;
                },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // PROVIDER AND FACILITY INFORMATION CARD
  // ---------------------------------------------------------

  Widget providerInformationCard() {
    if (isLoadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROVIDER INFORMATION',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  doctorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facilityName.isEmpty ? facilityCode : facilityName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Facility code: $facilityCode',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // BUILD SCREEN
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Medical Record',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Enter patient information and details of the visit.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),

                const SizedBox(height: 28),

                // MEDICAL RECORD FORM
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('Provider and Facility'),

                      providerInformationCard(),

                      sectionTitle('Patient Information'),

                      inputField(
                        'Patient National ID',
                        nationalIdController,
                        hint: 'Enter the registered National ID',
                        customValidator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Patient National ID is required';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (isPatientVerified || patientUID != null) {
                            setState(() {
                              isPatientVerified = false;
                              patientUID = null;
                              patientNameController.clear();
                            });
                          }
                        },
                      ),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isLookingUpPatient || isSaving
                              ? null
                              : lookupPatient,
                          icon: isLookingUpPatient
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_search),
                          label: Text(
                            isLookingUpPatient
                                ? 'Verifying Patient...'
                                : 'Verify Patient',
                          ),
                        ),
                      ),

                      if (isPatientVerified) ...[
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: AppColors.success,
                              size: 18,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Patient successfully verified',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),

                      inputField(
                        'Patient Full Name',
                        patientNameController,
                        hint: 'Automatically retrieved after verification',
                        readOnly: true,
                      ),

                      inputField(
                        'Age at Visit',
                        ageController,
                        keyboardType: TextInputType.number,
                      ),

                      sectionTitle('Clinical Information'),

                      inputField(
                        'Diagnosis',
                        diagnosisController,
                        hint: 'Enter diagnosis',
                        minLines: 2,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),

                      inputField(
                        'Prescription',
                        prescriptionController,
                        hint: 'Enter prescribed medication and dosage',
                        minLines: 2,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),

                      inputField(
                        'Laboratory Results',
                        labResultsController,
                        hint: 'Enter laboratory findings and results',
                        minLines: 2,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),

                      inputField(
                        'Treatment Notes',
                        notesController,
                        hint: 'Enter additional treatment notes',
                        minLines: 3,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),

                      sectionTitle('Visit Information'),

                      const Text(
                        'Visit date',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: visitDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );

                                if (selected != null && mounted) {
                                  setState(() {
                                    visitDate = selected;
                                  });
                                }
                              },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          '${visitDate.day}/${visitDate.month}/${visitDate.year}',
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              isSaving || isLoadingProfile || isLookingUpPatient
                              ? null
                              : saveRecord,
                          icon: isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            isSaving
                                ? 'Saving Record...'
                                : 'Save Medical Record',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // QR CODE APPEARS BELOW THE FORM AFTER SUCCESS.
                if (generatedRecordId != null) qrCodePanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
