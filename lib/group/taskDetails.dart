// taskDetails.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  TaskDetailsPage({required this.taskId, required this.taskData});

  @override
  _TaskDetailsPageState createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _commentController = TextEditingController();

  Future<void> _downloadFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      final downloadUrl = await ref.getDownloadURL();
      print("Download URL: $downloadUrl");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File downloaded successfully!')),
      );
    } catch (e) {
      print("Error downloading file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // String? assignedTo = widget.taskData['assignedTo'];
    String? fileUrl = widget.taskData['fileUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Task Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${widget.taskData['title']}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Description: ${widget.taskData['description'] ?? 'No description'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Due Date: / ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(widget.taskData['dueDate']))}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Assigned To: ${widget.taskData['assignedTo'] ?? 'Unassigned'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Priority: ${widget.taskData['priority'] ?? 'Normal'}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            if (fileUrl != null && fileUrl.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attached File:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_file),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fileUrl.split('/').last,
                          style: TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _downloadFile(fileUrl),
                        child: Text('Download'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Text('No file attached.'),
            SizedBox(height: 16),
            Text(
              'Comments:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('project_tasks')
                  .doc(widget.taskId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                if (snapshot.data!.docs.isEmpty) {
                  return Text('No comments yet.');
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> comment =
                        doc.data() as Map<String, dynamic>;
                    String userId = comment['userId'];
                    Timestamp? timestamp = comment['timestamp'] as Timestamp?;
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData)
                          return CircularProgressIndicator();
                        String username = userSnapshot.data!.exists
                            ? userSnapshot.data!['username']
                            : 'Unknown';
                        return ListTile(
                          title: Text(comment['text']),
                          subtitle: Text(
                            '$username${timestamp != null ? DateFormat('\t- yyyy-MM-dd -\t HH:mm').format(timestamp.toDate()) : "Pending..."}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      labelText: 'Add a comment',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () async {
                    if (_commentController.text.trim().isEmpty) return;
                    String userId = FirebaseAuth.instance.currentUser!.uid;
                    await _firestore
                        .collection('project_tasks')
                        .doc(widget.taskId)
                        .collection('comments')
                        .add({
                      'text': _commentController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                      'userId': userId,
                    });
                    _commentController.clear();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
