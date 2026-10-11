import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'splash_screen.dart';
import 'map_page.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb
        ? FirebaseOptions(
      apiKey: "AIzaSyCcnBrDiAOr-jktTmbmhDsrktIOT5oB8ZY",
      authDomain: "smart-bike-sharing.firebaseapp.com",
      projectId: "smart-bike-sharing",
      storageBucket: "smart-bike-sharing.appspot.com",
      messagingSenderId: "619570437052",
      appId: "1:619570437052:web:2655b89da532bb613d69b9",
    )
        : null,
  );

  runApp(MyApp()); // ✅ Now Firebase is initialized before app starts
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bike Sharing App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SplashScreen(), // ✅ Start with SplashScreen
    );
  }
}
