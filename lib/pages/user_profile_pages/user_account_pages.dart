import 'package:app1/models/user_model.dart';
import 'package:app1/provider/main_app_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserAccountPage extends StatelessWidget {
  Future<void> _pickUserProfileImage(BuildContext context) async {}

  AppUser? user;

  UserAccountPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        user = appState.user;
        return ListView(
          children: [
            SizedBox(
              height: 200,
              width: MediaQuery.of(context).size.width,
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade400,
                    backgroundImage: NetworkImage(user!.pfpUrl),
                    child: Icon(Icons.person, size: 40, color: Colors.white)
                        // user!.pfpUrl == ''
                        //     ? Icon(Icons.person, size: 40, color: Colors.white)
                        //     : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
