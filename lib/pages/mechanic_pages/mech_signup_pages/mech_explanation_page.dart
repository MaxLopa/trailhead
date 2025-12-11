import 'package:app1/pages/home_page.dart';
import 'package:app1/pages/mechanic_pages/mech_signup_pages/mech_signup_page.dart';
import 'package:flutter/material.dart';

class MechExplanationPage extends StatelessWidget {
  const MechExplanationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mechanic Explanation")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Implement all the bullshit for this legality stuff'),
            Padding(
              padding: EdgeInsetsGeometry.only(top: 20),
              child: DrawnButton(
                size: Size(150, 50),
                child: Text('Continue to sign up'),
                onClick: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MechSignupPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
