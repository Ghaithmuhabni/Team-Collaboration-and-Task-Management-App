// taskDetails.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
      if (fileUrl == null || fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No file attached.')),
        );
        return;
      }

      // Fetch the file from the URL
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        // Get the application documents directory
        Directory? appDocDir = await getApplicationDocumentsDirectory();

        // Extract the file name from the URL
        String fileName = Uri.parse(fileUrl).pathSegments.last;

        // Define the local file path
        String filePath = '${appDocDir.path}/$fileName';

        // Save the file to the device
        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File downloaded successfully!')),
        );
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      print("Error downloading file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file. Error: $e')),
      );
    }
    print("File URL: $fileUrl");
  }

  @override
  Widget build(BuildContext context) {
    String? fileUrl = widget.taskData['fileUrl'];
    String? assignedTo = widget.taskData['assignedTo'];
    String? priority = widget.taskData['priority'];
    DateTime dueDate = DateTime.parse(widget.taskData['dueDate']);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Task Details',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title: ${widget.taskData['title']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Description: ${widget.taskData['description'] ?? 'No description'}',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Due Date: ${DateFormat('yyyy-MM-dd / HH:mm').format(dueDate)}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Assigned To: ${assignedTo ?? 'Unassigned'}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.flag, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Priority: ${priority ?? 'Normal'}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (fileUrl != null && fileUrl.isNotEmpty)
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attached File:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.attach_file, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileUrl.split('/').last,
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _downloadFile(fileUrl),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 4, 135, 241),
                            ),
                            child: Text('Download'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No file attached.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ),
            Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comments:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    Divider(),
                    SizedBox(
                      height: 200, // Fixed height for scrollable area
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('project_tasks')
                            .doc(widget.taskId)
                            .collection('comments')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color.fromARGB(255, 4, 135, 241),
                                ),
                                strokeWidth: 3,
                              ),
                            );
                          }
                          if (snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No comments yet.'));
                          }
                          return ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              Map<String, dynamic> comment =
                                  snapshot.data!.docs[index].data()
                                      as Map<String, dynamic>;
                              String userId = comment['userId'];
                              Timestamp? timestamp =
                                  comment['timestamp'] as Timestamp?;
                              return FutureBuilder<DocumentSnapshot>(
                                future: _firestore
                                    .collection('users')
                                    .doc(userId)
                                    .get(),
                                builder: (context, userSnapshot) {
                                  if (!userSnapshot.hasData) {
                                    return CircularProgressIndicator();
                                  }
                                  String username = userSnapshot.data!.exists
                                      ? userSnapshot.data!['username']
                                      : 'Unknown';
                                  return ListTile(
                                    title: Text(comment['text']),
                                    subtitle: Text(
                                      '$username${timestamp != null ? DateFormat('\t- yyyy-MM-dd -\t HH:mm').format(timestamp.toDate()) : "Pending..."}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      labelText: 'Add a comment',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color.fromARGB(
                              255, 4, 135, 241), // Blue border
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color.fromARGB(
                              255, 4, 135, 241), // Blue border
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color.fromARGB(
                              255, 4, 135, 241), // Blue border
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color: const Color.fromARGB(255, 4, 135, 241)),
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
