import 'package:customer_app/screens/initial_checks_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:customer_app/firebase_options.dart';
import 'package:customer_app/screens/login_screen.dart';
import 'package:customer_app/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer App',
      theme: ThemeData(
        primarySwatch: MaterialColor(
          0xFFEF6800,
          <int, Color>{
            50: Color(0xFFFDECE0),
            100: Color(0xFFFAD0B3),
            200: Color(0xFFF7B180),
            300: Color(0xFFF4924D),
            400: Color(0xFFF17A26),
            500: Color(0xFFEF6800),
            600: Color(0xFFED6000),
            700: Color(0xFFEB5600),
            800: Color(0xFFE84D00),
            900: Color(0xFFE43C00),
          },
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: InitialChecksScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}