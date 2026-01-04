import 'package:app1/firebase_options.dart';
import 'package:app1/pages/home_page.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

//* Think of a way to reset the ServiceState a new page is pushed or popped
//* Find of a way to localize the providers or get rid of some so we don have so many global ones
//* Find a way to make fields more private e.g. user in appstate
//* Get new firebase account to implement storage

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}
