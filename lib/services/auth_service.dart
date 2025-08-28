import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Comprehensive authentication service for AllerTeens
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Collection reference for users
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('[AUTH_SERVICE] Starting Firebase Auth signup...');

      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        print('[AUTH_SERVICE] User credential returned null');
        return AuthResult.failure('Failed to create user account');
      }

      print('[AUTH_SERVICE] Firebase Auth user created: ${user.uid}');

      // Update display name
      print('[AUTH_SERVICE] Updating display name...');
      await user.updateDisplayName(name);

      // Send email verification
      print('[AUTH_SERVICE] Sending email verification...');
      print('[AUTH_SERVICE] Target email: ${user.email}');
      print('[AUTH_SERVICE] User UID: ${user.uid}');

      await user.sendEmailVerification();

      print('[AUTH_SERVICE] Email verification sent successfully!');
      print('[AUTH_SERVICE] Verification email sent to: ${user.email}');
      print('[AUTH_SERVICE] Please check your inbox and spam folder');
      print(
        '[AUTH_SERVICE] If no email received, check Firebase Console setup',
      );

      // Create user model
      print('[AUTH_SERVICE] Creating user model...');
      final userModel = UserModel.fromFirebaseUser(
        uid: user.uid,
        email: user.email!,
        displayName: name,
        photoUrl: user.photoURL,
        isEmailVerified: user.emailVerified,
      );
      print('[AUTH_SERVICE] User model created: ${userModel.toString()}');

      // Save user to Firestore
      print('[AUTH_SERVICE] Saving user to Firestore...');

      // Check if user document already exists
      final userExists = await this.userExists(user.uid);
      if (userExists) {
        print('[AUTH_SERVICE] User document already exists, using merge...');
        await _saveUserToFirestore(userModel, merge: true);
      } else {
        await _saveUserToFirestore(userModel, merge: false);
      }

      print('[AUTH_SERVICE] User saved to Firestore successfully');

      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      print('[AUTH_SERVICE] Firebase Auth error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      print('[AUTH_SERVICE] Unexpected error: $e');
      print('[AUTH_SERVICE] Error type: ${e.runtimeType}');
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('[AUTH_SERVICE] Starting Firebase Auth sign-in...');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        print('[AUTH_SERVICE] Sign-in returned null user');
        return AuthResult.failure('Failed to sign in');
      }

      print('[AUTH_SERVICE] Firebase Auth sign-in successful: ${user.uid}');

      // Get user from Firestore
      print('[AUTH_SERVICE] Getting user from Firestore...');
      final userModel = await _getUserFromFirestore(user.uid);

      if (userModel == null) {
        print('[AUTH_SERVICE] User not found in Firestore, creating new...');
        // Create user model if not exists (edge case)
        final newUserModel = UserModel.fromFirebaseUser(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          isEmailVerified: user.emailVerified,
        );
        await _saveUserToFirestore(newUserModel, merge: false);
        print('[AUTH_SERVICE] New user model created and saved');
        return AuthResult.success(newUserModel);
      }

      print('[AUTH_SERVICE] User found in Firestore: ${userModel.name}');
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      print(
        '[AUTH_SERVICE] Firebase Auth sign-in error: ${e.code} - ${e.message}',
      );
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      print('[AUTH_SERVICE] Unexpected sign-in error: $e');
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      print('[AUTH_SERVICE] Starting Google Sign-In flow...');

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('[AUTH_SERVICE] Google Sign-In was cancelled by user');
        return AuthResult.failure('Google Sign-In was cancelled');
      }

      print('[AUTH_SERVICE] Google account selected: ${googleUser.email}');

      // Obtain auth details
      print('[AUTH_SERVICE] Getting Google authentication details...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      print('[AUTH_SERVICE] Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      print('[AUTH_SERVICE] Signing in to Firebase with Google credential...');
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        print('[AUTH_SERVICE] Firebase sign-in returned null user');
        return AuthResult.failure('Failed to sign in with Google');
      }

      print('[AUTH_SERVICE] Firebase sign-in successful: ${user.uid}');

      // Check if user exists in Firestore
      print('[AUTH_SERVICE] Checking if user exists in Firestore...');
      UserModel? userModel = await _getUserFromFirestore(user.uid);

      if (userModel == null) {
        print('[AUTH_SERVICE] User not found in Firestore, creating new...');
        // Create new user in Firestore
        userModel = UserModel.fromFirebaseUser(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          isEmailVerified: user.emailVerified,
        );
        await _saveUserToFirestore(userModel, merge: false);
        print('[AUTH_SERVICE] New Google user created and saved');
      } else {
        print('[AUTH_SERVICE] Existing user found, updating info...');
        // Update existing user with latest info using merge to preserve existing data
        final updatedUser = userModel.copyWith(
          name: user.displayName ?? userModel.name,
          photoUrl: user.photoURL ?? userModel.photoUrl,
          isEmailVerified: user.emailVerified,
          updatedAt: DateTime.now(),
        );
        await _saveUserToFirestore(updatedUser, merge: true);
        userModel = updatedUser;
        print('[AUTH_SERVICE] User info updated with merge');
      }

      return AuthResult.success(userModel);
    } catch (e) {
      print('[AUTH_SERVICE] Google Sign-In error: $e');
      print('[AUTH_SERVICE] Error type: ${e.runtimeType}');
      return AuthResult.failure('Failed to sign in with Google: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      rethrow;
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to send password reset email: $e');
    }
  }

  /// Send email verification
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print(
          '[AUTH_SERVICE] No user is currently signed in for email verification',
        );
        return AuthResult.failure('No user is currently signed in');
      }

      // Development mode information
      if (kDebugMode) {
        print('[AUTH_SERVICE] DEVELOPMENT MODE DETECTED');
        print('[AUTH_SERVICE] In simulator: Firebase will send real emails');
        print(
          '[AUTH_SERVICE] For testing: Use the bypass option in the verification screen',
        );
        print('[AUTH_SERVICE] Or use a real email address you can access');
      }

      await user.sendEmailVerification();

      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      print(
        '[AUTH_SERVICE] Firebase Auth error sending email verification: ${e.code} - ${e.message}',
      );
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      print('[AUTH_SERVICE] Unexpected error sending email verification: $e');
      return AuthResult.failure('Failed to send email verification: $e');
    }
  }

  /// Get current user model from Firestore
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return await _getUserFromFirestore(user.uid);
  }

  /// Update user profile
  Future<AuthResult> updateUserProfile(UserModel userModel) async {
    try {
      await _saveUserToFirestore(userModel.copyWith(updatedAt: DateTime.now()));
      return AuthResult.success(userModel);
    } catch (e) {
      return AuthResult.failure('Failed to update user profile: $e');
    }
  }

  /// Save user to Firestore with merge option to prevent overwriting
  Future<void> _saveUserToFirestore(
    UserModel userModel, {
    bool merge = false,
  }) async {
    try {
      print('[AUTH_SERVICE] Converting user model to JSON...');
      final jsonData = userModel.toJson();
      print('[AUTH_SERVICE] User JSON: $jsonData');

      print('[AUTH_SERVICE] Saving to Firestore collection (merge: $merge)...');

      if (merge) {
        // Use merge to prevent overwriting existing user data
        await _usersCollection
            .doc(userModel.id)
            .set(jsonData, SetOptions(merge: true));
      } else {
        await _usersCollection.doc(userModel.id).set(jsonData);
      }

      print('[AUTH_SERVICE] Successfully saved to Firestore');
    } catch (e) {
      print('[AUTH_SERVICE] Error saving to Firestore: $e');
      print('[AUTH_SERVICE] Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Get user from Firestore
  Future<UserModel?> _getUserFromFirestore(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user from Firestore: $e');
      return null;
    }
  }

  /// Check if user exists in Firestore
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  /// Convert Firebase Auth error to user-friendly message
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again later.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    if (error is FirebaseAuthException) {
      return error.code == 'network-request-failed' ||
          error.code == 'unavailable';
    }
    return error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection');
  }
}

/// Result wrapper for authentication operations
class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? error;

  AuthResult._({required this.isSuccess, this.user, this.error});

  factory AuthResult.success(UserModel? user) {
    return AuthResult._(isSuccess: true, user: user);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }
}
