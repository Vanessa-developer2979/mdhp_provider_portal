
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

const Color primaryBlue = Color(0xFF1E3A8A);
const Color secondaryBlue = Color(0xFF3B82F6);
const Color pageBackground = Color(0xFFF8FAFC);
const Color darkText = Color(0xFF0F172A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderPortalApp());
}

class ProviderPortalApp extends StatelessWidget {
  const ProviderPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MDHP Provider Portal',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
        fontFamily: 'Roboto',
      ),
      home: const ProviderLoginScreen(),
    );
  }
}

// ======================================================
// PROVIDER LOGIN
// ======================================================

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() =>
      _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = profile.data();

      if (!profile.exists ||
          data == null ||
          data['role'] != 'provider' ||
          data['status'] != 'active') {
        await FirebaseAuth.instance.signOut();
        showMessage(
          'This account is not authorised as an active provider.',
        );
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderDashboard(
            providerName: data['fullName'] ?? 'Healthcare Provider',
            facilityId: data['facilityId'],
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Unable to sign in. Please try again.';

      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('An error occurred. Please check your connection.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.blueGrey),
      filled: true,
      fillColor: pageBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 750;

          return Row(
            children: [
              if (!compact)
                Expanded(
                  flex: 5,
                  child: Container(
                    color: primaryBlue,
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.health_and_safety,
                              color: Colors.white,
                              size: 42,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'MDHP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Better records.\nBetter healthcare.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 39,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'A connected digital health record system '
                          'for healthcare providers and citizens across Malawi.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16,
                            height: 1.7,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'MALAWI DIGITAL HEALTH PASSPORT',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 2,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                flex: compact ? 1 : 6,
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (compact) ...[
                          const Icon(
                            Icons.health_and_safety,
                            size: 50,
                            color: primaryBlue,
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sign in to access the healthcare provider portal.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 36),
                        const Text(
                          'Email address',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: inputDecoration(
                            'Enter your email',
                            Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Password',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          onSubmitted: (_) => login(),
                          decoration: inputDecoration(
                            'Enter your password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Center(
                          child: Text(
                            'Authorised healthcare personnel only',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ======================================================
// PROVIDER DASHBOARD
// ======================================================

class ProviderDashboard extends StatefulWidget {
  final String providerName;
  final String? facilityId;

  const ProviderDashboard({
    super.key,
    required this.providerName,
    this.facilityId,
  });

  @override
  State<ProviderDashboard> createState() =>
      _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  int selectedIndex = 0;

  void logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderLoginScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 245,
              color: primaryBlue,
              child: dashboardSidebar(),
            ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 75,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  color: Colors.white,
                  child: Row(
                    children: [
                      if (!isWide)
                        const Icon(
                          Icons.health_and_safety,
                          color: primaryBlue,
                          size: 30,
                        ),
                      if (!isWide) const SizedBox(width: 10),
                      Text(
                        isWide
                            ? 'Healthcare Provider Workspace'
                            : 'MDHP Provider Portal',
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.account_circle_outlined,
                        color: primaryBlue,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.providerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(width: 15),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: logout,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: [
                      dashboardHome(),
                      NewMedicalRecordScreen(
                        providerName: widget.providerName,
                        facilityId: widget.facilityId,
                      ),
                      const Center(
                        child: Text('Medical records workspace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_box_outlined),
                  label: 'New Record',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  label: 'Records',
                ),
              ],
            ),
    );
  }

  Widget dashboardSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 16, 38),
          child: Row(
            children: [
              Icon(
                Icons.health_and_safety,
                color: Colors.white,
                size: 37,
              ),
              SizedBox(width: 10),
              Text(
                'MDHP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        sidebarItem(Icons.dashboard_outlined, 'Overview', 0),
        sidebarItem(Icons.add_box_outlined, 'New Medical Record', 1),
        sidebarItem(Icons.folder_outlined, 'Medical Records', 2),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(22),
          child: Text(
            'MALAWI DIGITAL HEALTH PASSPORT\nHealthcare Provider Portal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              height: 1.7,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget sidebarItem(IconData icon, String label, int index) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 13),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardHome() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final recordsStream = FirebaseFirestore.instance
        .collection('medical_records')
        .where('providerUID', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: recordsStream,
      builder: (context, snapshot) {
        final count = snapshot.hasData
            ? snapshot.data!.docs.length
            : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  color: darkText,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, ${widget.providerName}. Here is your workspace.',
                style: const TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  overviewCard(
                    'Your Medical Records',
                    snapshot.hasError ? '—' : '$count',
                    Icons.folder_open_outlined,
                  ),
                  overviewCard(
                    'Provider Account',
                    'Active',
                    Icons.verified_user_outlined,
                  ),
                  overviewCard(
                    'Patient Records',
                    'Secure',
                    Icons.health_and_safety_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 35),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() => selectedIndex = 1);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Medical Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget overviewCard(String title, String value, IconData icon) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: secondaryBlue, size: 29),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              color: darkText,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// NEW MEDICAL RECORD FORM
// ======================================================

class NewMedicalRecordScreen extends StatefulWidget {
  final String providerName;
  final String? facilityId;

  const NewMedicalRecordScreen({
    super.key,
    required this.providerName,
    this.facilityId,
  });

  @override
  State<NewMedicalRecordScreen> createState() =>
      _NewMedicalRecordScreenState();
}

class _NewMedicalRecordScreenState
    extends State<NewMedicalRecordScreen> {
  final formKey = GlobalKey<FormState>();

  final patientUidController = TextEditingController();
  final patientNameController = TextEditingController();
  final ageController = TextEditingController();
  final diagnosisController = TextEditingController();
  final prescriptionController = TextEditingController();
  final labResultsController = TextEditingController();
  final notesController = TextEditingController();

  DateTime visitDate = DateTime.now();
  bool isSaving = false;

  @override
  void dispose() {
    patientUidController.dispose();
    patientNameController.dispose();
    ageController.dispose();
    diagnosisController.dispose();
    prescriptionController.dispose();
    labResultsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> saveRecord() async {
    if (!formKey.currentState!.validate()) return;

    final provider = FirebaseAuth.instance.currentUser;

    if (provider == null) return;

    setState(() => isSaving = true);

    try {
      final record = <String, dynamic>{
        'patientUID': patientUidController.text.trim(),
        'citizenName': patientNameController.text.trim(),
        'patientAgeAtVisit': int.parse(ageController.text.trim()),
        'providerUID': provider.uid,
        'providerName': widget.providerName,
        'facilityId': widget.facilityId,
        'diagnosis': diagnosisController.text.trim(),
        'prescription': prescriptionController.text.trim(),
        'labResults': labResultsController.text.trim(),
        'notes': notesController.text.trim(),
        'visitDate': Timestamp.fromDate(visitDate),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('medical_records')
          .add(record);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 50,
          ),
          title: const Text('Record submitted'),
          content: const Text(
            'The medical record was successfully saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                formKey.currentState!.reset();
                patientUidController.clear();
                patientNameController.clear();
                ageController.clear();
                diagnosisController.clear();
                prescriptionController.clear();
                labResultsController.clear();
                notesController.clear();
                setState(() => visitDate = DateTime.now());
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save medical record: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: primaryBlue,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget inputField(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
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
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint ?? 'Enter $label',
              filled: true,
              fillColor: pageBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }

              if (keyboardType == TextInputType.number &&
                  int.tryParse(value.trim()) == null) {
                return 'Enter a valid whole number';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

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
                    color: darkText,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the patient information and details of the visit.',
                  style: TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('Patient Information'),
                      inputField(
                        'Patient Firebase UID',
                        patientUidController,
                        hint: 'Enter the registered patient UID',
                      ),
                      inputField(
                        'Patient Full Name',
                        patientNameController,
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
                        maxLines: 3,
                      ),
                      inputField(
                        'Prescription',
                        prescriptionController,
                        maxLines: 3,
                      ),
                      inputField(
                        'Laboratory Results',
                        labResultsController,
                        maxLines: 3,
                      ),
                      inputField(
                        'Treatment Notes',
                        notesController,
                        maxLines: 4,
                      ),
                      sectionTitle('Visit Information'),
                      const Text(
                        'Visit date',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: visitDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );

                          if (selected != null) {
                            setState(() => visitDate = selected);
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
                          onPressed: isSaving ? null : saveRecord,
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
                            backgroundColor: primaryBlue,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
