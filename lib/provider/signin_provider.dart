import 'dart:io';

import 'package:app1/cubits/user_state.dart';
import 'package:app1/models/user_model.dart';
import 'package:app1/provider/main_app_provider.dart';
import 'package:app1/provider/service_provider.dart';
import 'package:app1/repositories/auth_repository.dart';
import 'package:app1/repositories/mech_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignInProvider extends ChangeNotifier {
  late UserCubit _userCubit;
  late AppState _appState;
  late AuthRepository _authRepo;
  late MechRepository _mechRepo;

  String email = '';
  String password = '';
  String name = '';
  String phone = '';
  Map<String, dynamic>? location;

  String bio = '';
  double rating = 0;
  int completedJobs = 0;

  bool firstStage;
  bool loginPage;

  SignInProvider() : firstStage = true, loginPage = true;

  void bind(
    UserCubit userCubit,
    AppState appState,
    AuthRepository authRepo,
    MechRepository mechRepo,
  ) {
    _userCubit = userCubit;
    _appState = appState;
    _authRepo = authRepo;
    _mechRepo = mechRepo;
  }

  void reset() {
    firstStage = true;
    email = '';
    password = '';
    name = '';
    phone = '';
    location = null;

    bio = '';
    notifyListeners();
  }

  /// Sign up the user and update the app state
  ///
  /// Creates new user in the auth system and in the database (object)
  /// Then updates the app state which pops current screen and notifies the user
  Future<void> signUp(BuildContext context) async {
    final newUser = AppUser(
      name: name,
      email: email,
      phone: phone,
      location: location,
      isMechanic: false,
    );

    await _userCubit.signUp(newUser, password);
    if (_userCubit.state is UserAuthed) {
      exit(0);
    }

    _appState.login(newUser);

    // region ##Fix this
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Signed Up!")));
    Navigator.pop(context);
    // endregion
  }

  /// Sign up as mechanic and update app state
  ///
  /// Creates mechanic profile in the database and links it to the user object
  /// Then updates all appropriate states and repositories to prepare queryies
  bool signUpAsMech() {
    var user = _appState.user!;
    var mech = Mech(
      name: user.name,
      bio: bio,
      rating: rating,
      completedJobs: completedJobs,
    );
    _appState.signInMech(mech);

    // ignore: unnecessary_null_comparison
    return _mechRepo.createMech(mech, user) != null;
  }

  /// Login existing user and update app state
  ///
  /// Initializes user session and fetches user data from the database
  /// Also intializies all further logic depending on the user data as well as possible mech profile
  Future<void> login(BuildContext context) async {
    final uid = await _authRepo.loginWithEmail(
      email: email,
      password: password,
    );
    final user = (await _userCubit.fetchUser(uid))!;

    _initUX_States(context, user); // TODO fix async issue
  }

  // ignore: non_constant_identifier_names
  /// Initialize all the necessary states after login
  ///
  /// Including possible mech profile, and all attached dependincies with repositories
  /// and main AppState
  Future<void> _initUX_States(BuildContext context, AppUser user) async {
    Mech? mech;

    var mechRepo = context.read<MechRepository>();
    var serviceState = context.read<ServiceState>();
    var appState = context.read<AppState>();

    serviceState.init(await mechRepo.fetchGenericGenres());

    if (user.isMechanic) {
      var mechRef = user.mechRef!;
      mech = await _mechRepo.fetchMech(mechRef);
    }

    appState.login(user, mech: mech);
  }
}
