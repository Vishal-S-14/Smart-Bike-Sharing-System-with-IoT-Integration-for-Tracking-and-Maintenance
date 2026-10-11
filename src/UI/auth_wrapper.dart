import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'map_page.dart';
import 'admin_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder(
            future: getUserRole(snapshot.data!.uid),
            builder: (context, AsyncSnapshot<String> roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (roleSnapshot.hasError || !roleSnapshot.hasData) {
                return LoginScreen();
              }
              return roleSnapshot.data == "Admin"
                  ? AdminDashboard()
                  : MapScreen(phoneNumber: "UserPhoneNumber");
            },
          );
        }

        return LoginScreen();
      },
    );
  }

  Future<String> getUserRole(String uid) async {
    var snapshot = await FirebaseFirestore.instance.collection('client').doc(uid).get();
    return snapshot.exists ? snapshot.get('Role') ?? 'User' : 'User';
  }
}
