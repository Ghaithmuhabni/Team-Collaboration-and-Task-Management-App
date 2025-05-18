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
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      // Check if the conversation document exists
      DocumentSnapshot conversationDoc = await _firestore
          .collection('messages')
          .doc(widget.conversationId)
          .get();

      if (!conversationDoc.exists) {
        // Create the conversation document if it doesn't exist
        await _firestore.collection('messages').doc(widget.conversationId).set({
          'lastMessage': text.trim(),
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });
      }

      // Add the message to Firestore
      await _firestore
          .collection('messages')
          .doc(widget.conversationId)
          .collection('chats')
          .add({
        'senderId': currentUserId,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the last message and timestamp in the conversation document
      await _firestore
          .collection('messages')
          .doc(widget.conversationId)
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(widget.otherUserId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Text('Loading...');
            return Text(snapshot.data!['username']);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .doc(widget.conversationId)
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
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
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[200] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(message['text']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
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
