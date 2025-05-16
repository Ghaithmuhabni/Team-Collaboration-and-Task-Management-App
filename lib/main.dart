import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/auth/login.dart';
import 'package:flutter_application_3/auth/useCases.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(), // Entry point for auth logic
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateMessageRoles() async {
    // Fetch all projects
    QuerySnapshot projectsSnapshot =
        await _firestore.collection('projects').get();

    for (var projectDoc in projectsSnapshot.docs) {
      String projectId = projectDoc.id;
      String managerId = projectDoc['managerId'];
      String clientId = projectDoc['client'];

      // Fetch all messages for the project
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('project_chats')
          .doc(projectId)
          .collection('messages')
          .get();

      for (var messageDoc in messagesSnapshot.docs) {
        String userId = messageDoc['userId'];
        String role = 'Member'; // Default role

        if (userId == managerId) {
          role = 'Manager';
        } else if (userId == clientId) {
          role = 'Client';
        }

        // Update the message with the role field
        if (messageDoc['role'] == null) {
          await messageDoc.reference.update({'role': role});
          print('Updated message ID: ${messageDoc.id} with role: $role');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Call the updateMessageRoles function when the app starts
    updateMessageRoles();

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(), // Listen for auth state changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data; // Get the current user
          if (user != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  String username = userSnapshot.data!['username'] ?? 'User';
                  return UseCasesPage(username: username);
                } else {
                  return LoginPage(); // Fallback to login if user data is missing
                }
              },
            );
          } else {
            return LoginPage(); // If no user is logged in, show the login page
          }
        }
        // Show a loading indicator while checking auth state
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
