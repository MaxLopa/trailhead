import 'package:app1/models/user_model.dart';
import 'package:app1/repositories/auth_repository.dart';
import 'package:app1/repositories/user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class UserState {}

class UserInitial extends UserState {}

class UserUnAuth extends UserState {}

class UserSigningIn extends UserState {}

class UserAuthed extends UserState {
  final AppUser user;

  UserAuthed(this.user);
}

class UserError extends UserState {
  final String message;

  UserError(this.message);
}

class UserCubit extends Cubit<UserState> {
  final UserRepository _userRepo;
  final AuthRepository _authRepo;

  UserCubit(this._userRepo, this._authRepo) : super(UserInitial());

  Future<void> signUp(AppUser newUser, String password) async {
    emit(UserSigningIn());
    try {
      final uid = await _authRepo.signUpWithEmail(
        email: newUser.email,
        password: password,
      );
      final userRef = await _userRepo.createUser(newUser);
      newUser.initalizeUser(userRef);
      emit(UserAuthed(newUser));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<AppUser?> fetchUser(String uid) async {
    emit(UserSigningIn());
    try {
      final user = await _userRepo.fetchUser(uid);
      emit(UserAuthed(user!));
      return user;
    } catch (e) {
      emit(UserError(e.toString()));
    }
    return null;
  }

  Future<DocumentReference> fetchUserRef(String uid) async {
    try {
      return FirebaseFirestore.instance.collection('users').doc(uid);
    } catch (e) {
      throw Exception('Failed to fetch user reference: $e');
    }
  }

  void signOut() {
    emit(UserUnAuth());
  }
}
