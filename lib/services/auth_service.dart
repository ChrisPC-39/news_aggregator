import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Email & Password Sign Up
  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create the user document immediately after sign-up.
      // This runs once — the doc won't exist yet at this point.
      await _createUserDocument(credential.user!.uid, email);

      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Try logging in.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'operation-not-allowed':
          return 'Email/Password accounts are not enabled in Firebase.';
        case 'weak-password':
          return 'The password is too weak. Use more characters.';
        case 'network-request-failed':
          return 'Check your internet connection.';
        default:
          return 'Sign up error: ${e.code}';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      // Map Firebase error codes to user-friendly messages
      switch (e.code) {
        case 'invalid-email':
          return "The email address is badly formatted.";
        case 'user-not-found':
          return "No user found with this email.";
        default:
          return e.message ?? "An unknown error occurred.";
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// Creates the initial user document in Firestore.
  /// All new users start as non-premium, non-admin.
  Future<void> _createUserDocument(String uid, String email) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'isPremium': false,
      'isAdmin': false,
      'stories': {},
    });
  }

  // Email & Password Login
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      // Map Firebase codes to normal error messages
      switch (e.code) {
        case 'invalid-email':
          return 'The email address is badly formatted.';
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'network-request-failed':
          return 'Check your internet connection.';
        case 'invalid-credential':
          return "Invalid credentials. Check your email and password.";
        default:
          return 'Error: ${e.code}';
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Google Sign In
  // Future<UserCredential?> signInWithGoogle() async {
  //   final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  //   if (googleUser == null) return null;
  //
  //   final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  //   final AuthCredential credential = GoogleAuthProvider.credential(
  //     accessToken: googleAuth.accessToken,
  //     idToken: googleAuth.idToken,
  //   );
  //
  //   return await _auth.signInWithCredential(credential);
  // }

  // Sign Out
  Future<void> signOut() async {
    // await _googleSignIn.signOut();
    await _auth.signOut();
  }
}