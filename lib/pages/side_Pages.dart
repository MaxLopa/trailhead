import 'package:app1/models/user_model.dart';
import 'package:app1/pages/home_page.dart';
import 'package:app1/provider/main_app_provider.dart';
import 'package:app1/provider/signin_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: MainLayout(bodyWidget: Container(child: Text(''))));
  }
}

class LoginSignupPage extends StatelessWidget {
  const LoginSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SignInProvider>(
      builder: (context, signInProvider, child) {
        return MainLayout(
          bodyWidget: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      signInProvider.loginPage = true;
                      signInProvider.notifyListeners();
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color:
                            signInProvider.loginPage
                                ? Colors.blue
                                : Colors.grey,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      signInProvider.loginPage = false;
                      signInProvider.notifyListeners();
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color:
                            !signInProvider.loginPage
                                ? Colors.blue
                                : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              if (signInProvider.loginPage)
                Form(child: LoginForm(provider: signInProvider))
              else
                SignUpForm(provider: signInProvider),
            ],
          ),
        );
      },
    );
  }

  static void openLogin(BuildContext context) {
    var provider = Provider.of<SignInProvider>(context, listen: false);
    provider.loginPage = true;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginSignupPage()),
    );
  }

  static void openSignUp(BuildContext context) {
    var provider = Provider.of<SignInProvider>(context, listen: false);
    provider.reset();
    provider.loginPage = false; // initialize the existing provider
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginSignupPage()),
    );
  }
}

class SignUpForm extends StatelessWidget {
  final GlobalKey<FormState> firstFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> secondFormKey = GlobalKey<FormState>();

  final SignInProvider provider;

  SignUpForm({required this.provider, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SignInProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child:
          provider
                  .firstStage // first stage of sign-up which includes email and password
              ? Form(
                key: firstFormKey,
                child: Column(
                  children: [
                    // Email collection
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter your email"
                                  : null,
                      onSaved: (value) => provider.email = value!.trim(),
                    ),
                    SizedBox(height: 16),
                    // Password collection
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator:
                          (value) =>
                              value == null || value.length < 6
                                  ? "Password must be at least 6 characters"
                                  : null,
                      onSaved: (value) => provider.password = value!.trim(),
                    ),
                    SizedBox(height: 16),
                    // Continue button
                    ElevatedButton(
                      // Validate, save and proceed to next stage
                      onPressed: () {
                        if (firstFormKey.currentState!.validate()) {
                          firstFormKey.currentState!.save();
                          provider.firstStage = false;
                          provider.notifyListeners();
                        }
                      },
                      child: Text('Continue'),
                    ),
                  ],
                ),
              )
              // Second stage of sign-up which includes phone num and name
              : Form(
                key: secondFormKey,
                child: Column(
                  children: [
                    Text('Additional sign-up details go here.'),
                    SizedBox(height: 16),
                    // Full name collection
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter your full name"
                                  : null,
                      onSaved: (value) => provider.name = value!.trim(),
                    ),
                    SizedBox(height: 16),
                    // Phone number collection
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? "Enter your phone number"
                                  : null,
                      onSaved: (value) => provider.phone = value!.trim(),
                    ),
                    SizedBox(height: 16),
                    // Sign Up button
                    ElevatedButton(
                      // Validate, save and complete sign-up
                      /*
                      Signup:
                       * 1. Check for validated Signup request from backend 
                       * 2. If success, show snackbar
                       * 3. Pop Current Page
                       * 4. Call provider.signUp() to update app state 
                      */
                      onPressed: () {
                        if (secondFormKey.currentState!.validate()) {
                          secondFormKey.currentState!.save();
                          provider.signUp(context);
                        }
                      },
                      child: Text('Sign Up!'),
                    ),
                  ],
                ),
              ),
    );
  }
}

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final SignInProvider provider;

  LoginForm({required this.provider, super.key});

  void _login(BuildContext context) {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logged in with ${provider.email}... Hows it going "),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context);
        provider.login(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? "Enter your email"
                          : null,
              onSaved: (value) => provider.email = value!.trim(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator:
                  (value) =>
                      value == null || value.length < 6
                          ? "Password must be at least 6 characters"
                          : null,
              onSaved: (value) => provider.password = value!.trim(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  AppUser? user;
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        user = appState.user;
        return MainLayout(
          bodyWidget: Column(
            children: [
              Text('Profile Page'),

              SizedBox(
                height: 200,
                width: MediaQuery.of(context).size.width,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      backgroundImage: NetworkImage(user!.pfpUrl),
                      child:
                          user!.pfpUrl == ''
                              ? Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.black,
                              )
                              : null,
                    ),
                  ),
                ),
              ),

              Text('Name: ${appState.user?.name ?? ''}'),
              Text('Email: ${appState.user?.email ?? ''}'),
              ElevatedButton(
                onPressed: () {
                  appState.logout(context);
                  Navigator.pop(context);
                },
                child: Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  }
}
