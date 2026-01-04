import 'package:app1/cubits/job_state.dart';
import 'package:app1/cubits/user_state.dart';
import 'package:app1/devhelp_pages/dev_mock_booking.dart';
import 'package:app1/pages/booking_page.dart';
import 'package:app1/devhelp_pages/dev_servaddition_page.dart';
import 'package:app1/pages/mechanic_pages/mech_setup_pages/mech_dashboard.dart';
import 'package:app1/pages/side_Pages.dart';
import 'package:app1/provider/mech_provider.dart';
import 'package:app1/provider/signin_provider.dart';
import 'package:app1/repositories/auth_repository.dart';
import 'package:app1/repositories/mech_repository.dart';
import 'package:app1/repositories/service_dev_repository.dart';
import 'package:app1/repositories/user_repository.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../provider/service_provider.dart';
import '../provider/main_app_provider.dart';

//* Think of a way to reset the ServiceState a new page is pushed or popped
//* Find of a way to localize the providers or get rid of some so we don have so many global ones
//* Find a way to make fields more private e.g. user in appstate

//*** Implement a global open method that is shared between Page widgets that require a check before opening them (e.g. is the user logged in?)

class MyApp extends StatelessWidget {
  static const TextStyle buttonStyle = TextStyle(
    fontSize: 15,
    color: Colors.black,
  );

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // repositories (make sure these exist in your project)
        Provider(create: (_) => UserRepository()),
        Provider(create: (_) => AuthRepository()),
        Provider(create: (_) => JobRepository()),
        Provider(
          create: (ctx) => MechRepository(userRepo: ctx.read<UserRepository>()),
        ),
        Provider(create: (_) => ServiceDevRepository()),

        // cubits (can now read the repos)
        BlocProvider(
          create:
              (ctx) => UserCubit(
                ctx.read<UserRepository>(),
                ctx.read<AuthRepository>(),
              ),
        ),
        BlocProvider(create: (ctx) => JobCubit(ctx.read<JobRepository>())),

        // app-states
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => ServiceState()),
        ChangeNotifierProvider(create: (_) => MechProvider()),
        ChangeNotifierProxyProvider3<
          UserCubit,
          AppState,
          AuthRepository,
          SignInProvider
        >(
          create: (context) => SignInProvider(),
          update:
              (context, userCubit, appState, authRepo, provider) =>
                  provider!..bind(
                    userCubit,
                    appState,
                    authRepo,
                    context.read<MechRepository>(),
                  ),
        ),
      ],
      child: MaterialApp(
        title: 'Basic Menu App',
        home: HomePage(),
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  final Widget bodyWidget;

  const MainLayout({required this.bodyWidget, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Consumer<AppState>(
          builder: (context, provider, child) {
            return PencilBox(
              drawTop: false,
              drawLeft: false,
              drawRight: false,
              width: MediaQuery.of(context).size.width,
              height: 70,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Row(
                      children: [
                        DrawnButton(
                          size: Size(90, 30),
                          onClick: () {
                            BookingPage.open(context);
                          },
                          child: Text('Book', style: MyApp.buttonStyle),
                        ),
                        SizedBox(width: 8),
                        Consumer<MechRepository>(
                          builder: (context, repo, child) {
                            return DrawnButton(
                              size: Size(90, 30),
                              onClick: () => MechDash.enterMechPage(context),
                              child: Text('Fix', style: MyApp.buttonStyle),
                            );
                          },
                        ),
                      ],
                    ),

                    Spacer(),

                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        overlayColor: Colors.transparent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
                        );
                      },
                      child: Text(
                        'Trailhead Mechanics',
                        style: TextStyle(fontSize: 35),
                      ),
                    ),

                    Spacer(),

                    if (provider.loggedIn())
                      Row(
                        children: [
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfilePage(),
                                ),
                              );
                            },
                            icon: Icon(Icons.person),
                          ),
                          DrawnButton(
                            onClick: () {
                              provider.logout(context);
                            },
                            size: Size(100, 30),
                            child: Text('Log out', style: MyApp.buttonStyle),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          DrawnButton(
                            onClick: () {
                              LoginSignupPage.openSignUp(context);
                            },
                            size: Size(100, 30),
                            child: Text('Sign up', style: MyApp.buttonStyle),
                          ),
                          SizedBox(width: 8),
                          DrawnButton(
                            onClick: () {
                              LoginSignupPage.openLogin(context);
                            },
                            size: Size(90, 30),
                            child: Text('Log in', style: MyApp.buttonStyle),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Flexible(child: bodyWidget),
          Container(
            decoration: BoxDecoration(color: CupertinoColors.systemGrey2),
            child: Row(
              children: [
                // ElevatedButton(
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.white,
                //     foregroundColor: Colors.black,
                //
                //     side: BorderSide(color: Colors.black, width: 2),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(3),
                //     ),
                //   ),
                //   onPressed: () {},
                //   child: Text(
                //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                //     'Contact Us',
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      bodyWidget: ListView(
        key: Key('Scrolling View'),
        children: [
          Container(
            key: Key('Content Container'),
            color: CupertinoColors.darkBackgroundGray,
            alignment: Alignment.center,
            child: Stack(
              key: Key('Home Image Stack'),
              children: [
                Image.asset(
                  'assets/images/drawing.png',
                  fit: BoxFit.fitWidth,
                  width: MediaQuery.of(context).size.width,
                ),
                Positioned(
                  left: 40,
                  bottom: 220,
                  child: DrawnButton(
                    size: Size(120, 30),
                    onClick: () {},
                    child: Text(
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      'Fix bike!',
                    ),
                  ),
                ),
                Positioned(
                  right: 100,
                  bottom: 300,
                  child: DrawnButton(
                    size: Size(120, 30),
                    onClick: () {},
                    child: Text(
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      'About Us',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            key: Key('Options Container'),
            padding: EdgeInsets.only(top: 30),
            width: MediaQuery.of(context).size.width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PageOptionBox(
                  'Become a Mechanic!',
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 15, bottom: 15),
                        child: Text(
                          'Start Wrenching on bikes \nin your own space \nwith your own tools',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 25, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                PageOptionBox(
                  'Get your Bike Fixed !',
                  left: false,
                  right: false,
                  child: Column(
                    children: [
                      Image.network(
                        'https://img.redbull.com/images/c_crop,w_5568,h_2784,x_0,y_444/c_auto,w_1200,h_630/f_auto,q_auto/redbullcom/2018/07/10/4f0eb2e5-f6fa-4ca6-98ff-29a0701516ea/mtb-collection',
                        width: 200,
                        height: 200,
                      ),
                    ],
                  ),
                ),
                PageOptionBox('Recent History', child: Text('hello')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageOptionBox extends StatelessWidget {
  final Text headerText;
  final Widget child;
  final double height;
  final double widthScale;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  PageOptionBox(
    String bodyText, {
    super.key,
    required this.child,
    this.height = 400,
    this.widthScale = 3,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  }) : headerText = Text(
         bodyText,
         style: TextStyle(
           color: Colors.black,
           fontSize: 38,
           fontWeight: FontWeight.bold,
         ),
       );

  @override
  Widget build(BuildContext context) {
    return PencilBox(
      drawTop: top,
      drawBottom: bottom,
      drawLeft: left,
      drawRight: right,
      width: MediaQuery.of(context).size.width / widthScale,
      height: height,
      child: Container(
        child: Column(
          children: [
            SizedBox(
              key: Key('Option Title'),
              width: MediaQuery.of(context).size.width / 3 - 5.4,
              child: Container(
                alignment: Alignment.topCenter,
                padding: EdgeInsets.only(top: 8),
                child: headerText,
              ),
            ),
            Container(
              key: Key('Option body'),
              decoration: BoxDecoration(color: Colors.white),
              width: MediaQuery.of(context).size.width / 3 - 5.4,
              height: 300,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  //  //
}

class DrawnButton extends StatelessWidget {
  static const int minButtonID = 1;
  static const int maxButtonID = 2;

  final Random random = Random();
  final Widget? child;
  final Size size;
  final Function()? onClick;

  DrawnButton({super.key, this.child, required this.size, this.onClick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,

      child: Stack(
        children: [
          Image.asset(
            getButtonImageID(),
            width: size.width,
            height: size.height,
            fit: BoxFit.fill,
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(30)),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              foregroundColor: Colors.black,
              fixedSize: Size(size.width, size.height),
            ),
            onPressed: onClick,
            child: child,
          ),
        ],
      ),
    );
  }

  String getButtonImageID() {
    int buttonIndex = random.nextInt(maxButtonID) + 1;
    return 'assets/images/button$buttonIndex.png';
  }
}

class PencilLine extends StatelessWidget {
  final double width;
  final double height; // vertical amplitude range
  final Color color;
  final double strokeWidth;

  const PencilLine({
    super.key,
    required this.width,
    this.height = 3,
    this.color = Colors.black,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: PencilLinePainter(
        height: height,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class PencilLinePainter extends CustomPainter {
  final double height;
  final Color color;
  final double strokeWidth;

  PencilLinePainter({
    required this.height,
    required this.color,
    required this.strokeWidth,
  });

  final Random _random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path = Path();

    // Calculate segment count dynamically based on line width
    final desiredSegmentWidth = 50.0;
    final segments = (size.width / desiredSegmentWidth).floor().clamp(1, 100);
    final segmentWidth = size.width / segments;

    path.moveTo(0, size.height / 2);

    for (int i = 0; i < segments; i++) {
      final x1 = i * segmentWidth;
      final x2 = (i + 1) * segmentWidth;
      final midX = (x1 + x2) / 2;

      final controlY = size.height / 2 + (_random.nextDouble() - 0.5) * height;

      path.quadraticBezierTo(midX, controlY, x2, size.height / 2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PencilBox extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final EdgeInsets padding;
  final double wobbleHeight;
  final double strokeWidth;
  final Color color;
  final bool expanded;
  final bool drawTop;
  final bool drawRight;
  final bool drawBottom;
  final bool drawLeft;

  const PencilBox({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.padding = const EdgeInsets.all(16),
    this.wobbleHeight = 10,
    this.strokeWidth = 2,
    this.color = Colors.black,
    this.expanded = false,
    this.drawTop = true,
    this.drawRight = true,
    this.drawBottom = true,
    this.drawLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: expanded ? SizedBox.expand(child: child) : child,
    );

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PencilBoxPainter(
          strokeWidth: strokeWidth,
          wobbleHeight: wobbleHeight,
          color: color,
          drawTop: drawTop,
          drawRight: drawRight,
          drawBottom: drawBottom,
          drawLeft: drawLeft,
        ),
        child: content,
      ),
    );
  }
}

class _PencilBoxPainter extends CustomPainter {
  final double wobbleHeight;
  final double strokeWidth;
  final Color color;
  final bool drawTop;
  final bool drawRight;
  final bool drawBottom;
  final bool drawLeft;
  final Random _random = Random();

  _PencilBoxPainter({
    required this.wobbleHeight,
    required this.strokeWidth,
    required this.color,
    required this.drawTop,
    required this.drawRight,
    required this.drawBottom,
    required this.drawLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final topLeft = Offset(0, 0);
    final topRight = Offset(size.width, 0);
    final bottomRight = Offset(size.width, size.height);
    final bottomLeft = Offset(0, size.height);

    if (drawTop) {
      canvas.drawPath(
        _generateSquigglyPath(topLeft, topRight, wobbleHeight),
        paint,
      );
    }
    if (drawRight) {
      canvas.drawPath(
        _generateSquigglyPath(
          topRight,
          bottomRight,
          wobbleHeight,
          vertical: true,
        ),
        paint,
      );
    }
    if (drawBottom) {
      canvas.drawPath(
        _generateSquigglyPath(bottomRight, bottomLeft, wobbleHeight),
        paint,
      );
    }
    if (drawLeft) {
      canvas.drawPath(
        _generateSquigglyPath(
          bottomLeft,
          topLeft,
          wobbleHeight,
          vertical: true,
        ),
        paint,
      );
    }
  }

  Path _generateSquigglyPath(
    Offset start,
    Offset end,
    double amplitude, {
    bool vertical = false,
  }) {
    final path = Path();
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = vertical ? dy.abs() : dx.abs();
    final direction = (vertical ? dy.sign : dx.sign);

    final desiredSegmentLength = 100.0;
    final segments = (length / desiredSegmentLength).floor().clamp(1, 100);
    final segmentLength = length / segments;

    path.moveTo(start.dx, start.dy);

    for (int i = 0; i < segments; i++) {
      final t1 = i * segmentLength;
      final t2 = (i + 1) * segmentLength;
      final mid = (t1 + t2) / 2;
      final controlOffset = (_random.nextDouble() - 0.5) * amplitude;

      if (vertical) {
        final cx = start.dx + controlOffset;
        final cy = start.dy + mid * direction;
        final ex = start.dx;
        final ey = start.dy + t2 * direction;
        path.quadraticBezierTo(cx, cy, ex, ey);
      } else {
        final cx = start.dx + mid * direction;
        final cy = start.dy + controlOffset;
        final ex = start.dx + t2 * direction;
        final ey = start.dy;
        path.quadraticBezierTo(cx, cy, ex, ey);
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
