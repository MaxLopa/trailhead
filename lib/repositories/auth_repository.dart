import 'package:firebase_auth/firebase_auth.dart';
import 'package:app1/repositories/user_repository.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final UserRepository _userRepo;

  AuthRepository({FirebaseAuth? auth, UserRepository? userRepo})
    : _auth = auth ?? FirebaseAuth.instance,
      _userRepo = userRepo ?? UserRepository();

  Future<String> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    // Step 1: Create Auth account
    final userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCred.user!.uid;
  }

  Future<String> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCred.user == null ? 'Couldn\'t log in' : userCred.user!.uid;
  }
}
