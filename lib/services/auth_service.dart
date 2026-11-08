import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('Unable to authenticate your account.');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();

    if (!profile.exists) {
      await _auth.signOut();
      throw Exception(
        'Your provider profile could not be found. '
        'Please contact your administrator.',
      );
    }

    final data = profile.data()!;

    if (data['role'] != 'provider' || data['status'] != 'active') {
      await _auth.signOut();
      throw Exception(
        'Your account is not authorised to access the provider portal.',
      );
    }

    return data;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
