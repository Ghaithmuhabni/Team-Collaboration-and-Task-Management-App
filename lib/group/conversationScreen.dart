// conversationScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;

  ConversationScreen({
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String currentUserId;

  // Generate a unique conversation ID for a pair of users
  String generateConversationId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort(); // Sort IDs alphabetically
    return '${ids[0]}_${ids[1]}'; // Combine them with an underscore
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      String conversationId =
          generateConversationId(currentUserId, widget.otherUserId);

      // Check if the conversation document exists
      DocumentSnapshot conversationDoc = await _firestore
          .collection('one_one_conversation')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // Create the conversation document if it doesn't exist
        await _firestore
            .collection('one_one_conversation')
            .doc(conversationId)
            .set({
          'lastMessage': text.trim(),
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
      }

      // Add the message to Firestore
      await _firestore
          .collection('one_one_conversation')
          .doc(conversationId)
          .collection('chats')
          .add({
        'senderId': currentUserId,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the last message and timestamp in the conversation document
      await _firestore
          .collection('one_one_conversation')
          .doc(conversationId)
          .update({
        'lastMessage': text.trim(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Clear the text field after successful message sending
      setState(() {
        _messageController.clear();
      });
    } catch (e) {
      // Log the error for debugging purposes
      print("Error sending message: $e");

      // Show a SnackBar only if there's a genuine error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    String conversationId =
        generateConversationId(currentUserId, widget.otherUserId);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(widget.otherUserId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Text('Loading...');
            return Text(snapshot.data!['username']);
          },
        ),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
        elevation: 0, // Remove shadow for a cleaner look
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('one_one_conversation')
                  .doc(conversationId)
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color.fromARGB(255, 4, 135, 241), // Blue theme
                      ),
                    ),
                  );
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No messages yet.\nStart the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    bool isMe = message['senderId'] == currentUserId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color.fromARGB(
                                  255, 4, 135, 241) // Blue theme
                              : Colors.grey[300], // Light grey for others
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message['text'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color:
                          const Color.fromARGB(255, 4, 135, 241)), // Blue theme
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
