// profilePage.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/componants/drawer.dart';

class ProfilePage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _changePassword(BuildContext context) async {
    final TextEditingController _oldPasswordController =
        TextEditingController();
    final TextEditingController _newPasswordController =
        TextEditingController();
    final TextEditingController _confirmPasswordController =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Old Password'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'New Password'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              String oldPassword = _oldPasswordController.text.trim();
              String newPassword = _newPasswordController.text.trim();
              String confirmPassword = _confirmPasswordController.text.trim();

              if (oldPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill all fields.')),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('New password and confirmation do not match.')),
                );
                return;
              }

              try {
                User? user = _auth.currentUser;
                AuthCredential credential = EmailAuthProvider.credential(
                  email: user!.email!,
                  password: oldPassword,
                );

                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password updated successfully!')),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Failed to update password: ${e.toString()}')),
                );
              }
            },
            child: Text('Update'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return CircularProgressIndicator();

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      drawer: AppDrawer(),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('users').doc(currentUser.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: CircularProgressIndicator());
          }

          Map<String, dynamic> userData =
              snapshot.data!.data() as Map<String, dynamic>;

          // Get the name from Firebase Auth or Firestore
          String displayName = currentUser.displayName ??
              userData['username'] ??
              'User'; // Default to "User" if no name is found

          return FutureBuilder(
            future: Future.wait([
              _firestore
                  .collection('personal_tasks')
                  .where('uid', isEqualTo: currentUser.uid)
                  .get(),
              _firestore
                  .collection('projects')
                  .where('members', arrayContains: currentUser.uid)
                  .get(),
            ]),
            builder: (context, AsyncSnapshot<List<QuerySnapshot>> snapshots) {
              if (!snapshots.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              int personalTaskCount = snapshots.data![0].docs.length;
              int projectParticipationCount = snapshots.data![1].docs.length;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name: $displayName',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Email: ${currentUser.email}',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Personal Tasks: $personalTaskCount',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Projects Participated In: $projectParticipationCount',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _changePassword(context),
                      child: Text('Change Password'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
