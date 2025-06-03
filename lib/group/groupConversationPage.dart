// GroupConversationPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GroupConversationPage extends StatefulWidget {
  final String projectId;

  GroupConversationPage({required this.projectId});

  @override
  _GroupConversationPageState createState() => _GroupConversationPageState();
}

class _GroupConversationPageState extends State<GroupConversationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _messageController = TextEditingController();

  Future<void> _sendMessage(String projectId, String message) async {
    String currentUserId = _auth.currentUser!.uid;
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    String username = currentUserDoc['username'] ?? 'Unknown';

    // Determine the user's role (manager, client, or member)
    String role = 'Member'; // Default role
    DocumentSnapshot projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (projectDoc['managerId'] == currentUserId) {
      role = 'Manager';
    } else if (projectDoc['client'] == currentUserId) {
      role = 'Client';
    }

    // Add the message to Firestore
    await _firestore
        .collection('project_conversation') // Updated collection name
        .doc(projectId)
        .collection('messages')
        .add({
      'userId': currentUserId,
      'username': username,
      'message': message,
      'role': role, // Store the user's role
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update the last message details in the parent document
    await _firestore.collection('project_conversation').doc(projectId).set({
      'lastMessage': message,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastSeen': {
        currentUserId:
            FieldValue.serverTimestamp(), // Mark as read for the sender
      },
    }, SetOptions(merge: true));

    _messageController.clear(); // Clear the input field after sending
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('projects').doc(widget.projectId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text('Loading...');
            }
            String projectName = snapshot.data!['title'] ?? 'Project';
            return Text(
                "$projectName Conversation", // Display the project name in the AppBar
                style: TextStyle(fontSize: 18, color: Colors.white));
          },
        ),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('project_conversation') // Updated collection name
                  .doc(widget.projectId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          const Color.fromARGB(255, 4, 135, 241)),
                    ),
                  );
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true, // Display newest messages at the bottom
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    String username = message['username'];
                    String text = message['message'];
                    String role = message['role'] ?? 'Member'; // Default role
                    DateTime timestamp =
                        (message['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now(); // Handle missing timestamp

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _auth.currentUser!.uid == message['userId']
                          ? Colors.blue[50] // Light blue for own messages
                          : Colors.grey[100], // Grey for others' messages
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[200],
                          child: Text(
                            username[0]
                                .toUpperCase(), // Show first letter of username
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          '$username ($role)', // Display username and role
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text),
                            SizedBox(height: 4),
                            Text(
                              DateFormat('HH:mm')
                                  .format(timestamp), // Display timestamp
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color.fromARGB(255, 4, 135, 241),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color.fromARGB(255, 4, 135, 241),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color.fromARGB(255, 4, 135, 241),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color: const Color.fromARGB(255, 4, 135, 241)),
                  onPressed: () {
                    if (_messageController.text.trim().isNotEmpty) {
                      _sendMessage(widget.projectId, _messageController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
