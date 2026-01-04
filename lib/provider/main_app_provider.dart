
import 'package:app1/models/user_model.dart';
import 'package:app1/pages/home_page.dart';
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  AppUser? user;
  Mech? mech;
  DateTime? _selectedDate;

  // User? get user => _user;
  DateTime? get selectedDate => _selectedDate;

  bool jobApproved = false;

  bool loggedIn() => user != null;

  /// Initializes rest of app state after login
  void login(AppUser user, {Mech? mech}) {
    this.user = user;
    signInMech(mech);

    notifyListeners();
  }

  /// Nulls/Removes all previous user and app data relating to user and navigates to HomePage
  AppUser logout(BuildContext context) {
    final temptUser = user;
    user = null;

    _selectedDate = null;
    notifyListeners();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Logged out.")));

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomePage()),
      (Route<dynamic> route) => false,
    );
    return temptUser!;
  }

  /// Called to initialize/sign in mechanic data in app state
  void signInMech(Mech? mech) {
    this.mech = mech;
    // notifyListeners();
  }

  bool isMech() => user?.isMechanic ?? false;
}
