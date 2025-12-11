import 'package:app1/pages/home_page.dart';
import 'package:app1/pages/mechanic_pages/mech_setup_pages/mech_dashboard.dart';
import 'package:app1/provider/signin_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Basically for mechanic to enter their profile details before becoming a mechanic
class MechSignupPage extends StatelessWidget {
  final GlobalKey<FormState> firstFormKey = GlobalKey<FormState>();

  MechSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      bodyWidget: Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<SignInProvider>(
          builder: (context, provider, child) {
            return Form(
              key: firstFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entering Bio
                  Text(
                    "Mechanic Profile",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? "Enter a bio"
                                : null,
                    onSaved: (value) {
                      provider.bio = value!;
                    },
                  ),
                  SizedBox(height: 16),

                  // TextFormField(
                  //   decoration: InputDecoration(
                  //     labelText: 'Skills (comma separated)',
                  //     border: OutlineInputBorder(),
                  //   ),
                  //   validator: (value) => value == null || value.isEmpty
                  //       ? "Enter at least one skill"
                  //       : null,
                  //   onSaved: (value) {
                  //     // later parse into list<String>
                  //   },
                  // ),
                  // SizedBox(height: 16),
                  Center(
                    // Sign Up Button
                    child: ElevatedButton(
                      // 
                      onPressed: () {
                        if (firstFormKey.currentState!.validate()) {
                          firstFormKey.currentState!.save();

                          if (provider.signUpAsMech()) {
                            MechDash.enterMechPage(context,);
                          } else {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          }

                          provider.notifyListeners();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Signed Up as Mechanic!")),
                          );
                        }
                      },
                      child: Text("Sign Up!"),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
