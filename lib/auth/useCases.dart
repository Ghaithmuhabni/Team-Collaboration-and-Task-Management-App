// UseCasesPage.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_3/componants/drawer.dart';
import 'login.dart';
import '../biryesel/biryeselUI.dart'; // Import the Personal Use UI
import '../group/groupListUI.dart'; // Import the Group UI

class UseCasesPage extends StatelessWidget {
  final String username;

  UseCasesPage({required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Use Case'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hello, $username'),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PersonalUsePage()),
                );
              },
              child: Text('Personal Use'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GroupUIPage()),
                );
              },
              child: Text('Group Use'),
            ),
          ],
        ),
      ),
    );
  }
}