import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/group/editTaskProject.dart';
import 'package:flutter_application_3/group/taskDetails.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // Import AwesomeDialog

class NewTaskPage extends StatelessWidget {
  final String projectId;
  NewTaskPage({required this.projectId});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Function to get priority color
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red[300]!;
      case 'Normal':
        return Colors.orange[300]!;
      case 'Low':
        return Colors.green[300]!;
      default:
        return Colors.grey[200]!;
    }
  }

  // Function to get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Started':
        return Icons.play_arrow;
      case 'Continues':
        return Icons.timelapse;
      case 'Finished':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  // Delete a task
  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('project_tasks').doc(taskId).delete();
  }

  // Show edit/delete dialog using AwesomeDialog
  void _showEditDeleteDialog(
      BuildContext context, DocumentSnapshot task) async {
    String currentUserId = _auth.currentUser!.uid;

    // Fetch project document to check if the current user is the manager
    DocumentSnapshot projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    String managerId = projectDoc['managerId'] ?? '';

    if (currentUserId != managerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only the project manager can edit or delete tasks.'),
        ),
      );
      return;
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: 'Edit or Delete Task',
      desc: 'Would you like to edit or delete this task?',
      btnOkText: 'Edit',
      btnOkOnPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditTaskProjectPage(
              taskId: task.id,
              taskData: task.data() as Map<String, dynamic>,
            ),
          ),
        );
      },
      btnCancelText: 'Delete',
      btnCancelOnPress: () async {
        await _deleteTask(task.id);
      },
    ).show();
  }

  // Check if the current user can view task details
  Future<bool> _canViewTaskDetails(String assignedTo) async {
    String currentUserId = _auth.currentUser!.uid;

    // Fetch project document to get manager ID and client ID
    DocumentSnapshot projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    String managerId = projectDoc['managerId'] ?? '';
    String clientId = projectDoc['client'] ?? '';

    // Fetch current user document to get their username
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    String currentUsername = currentUserDoc['username'] ?? 'Unknown';

    // Allow access if the user is the manager, client, or task owner
    return currentUserId == managerId ||
        currentUserId == clientId ||
        currentUsername == assignedTo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Tasks',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('project_tasks')
            .where('projectId', isEqualTo: projectId)
            .where('status', isEqualTo: 'Pending')
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
                  Icon(Icons.task_alt, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'No new tasks found.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var task = snapshot.data!.docs[index];
              DateTime dueDate = DateTime.parse(task['dueDate']);
              String assignedUsername = task['assignedTo'] ?? 'Unassigned';
              String taskStatus =
                  task['status'] ?? 'Started'; // Default to "Started"
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(_auth.currentUser!.uid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(
                      title: Text(task['title']),
                      subtitle: Text('Loading...'),
                    );
                  }
                  String currentUsername =
                      userSnapshot.data!['username'] ?? 'Unknown';
                  bool isCurrentUserAssigned =
                      currentUsername == assignedUsername;
                  return GestureDetector(
                    onTap: () async {
                      bool canView =
                          await _canViewTaskDetails(assignedUsername);
                      if (canView) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskDetailsPage(
                              taskId: task.id,
                              taskData: task.data() as Map<String, dynamic>,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'You do not have permission to view this task.'),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      _showEditDeleteDialog(context, task);
                    },
                    child: Card(
                      margin: EdgeInsets.all(10),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _getPriorityColor(task['priority']),
                      child: ListTile(
                        title: Text(
                          task['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Assigned To: '),
                                Text(
                                  assignedUsername,
                                  style: TextStyle(
                                    color: isCurrentUserAssigned
                                        ? Colors.red
                                        : null,
                                    fontWeight: isCurrentUserAssigned
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                    'Due: ${DateFormat('yyyy-MM-dd / HH:mm').format(dueDate)}'),
                              ],
                            ),
                          ],
                        ),
                        trailing: isCurrentUserAssigned
                            ? DropdownButton<String>(
                                value: [
                                  'Pending',
                                  'Started',
                                  'Continues',
                                  'Finished'
                                ].contains(taskStatus)
                                    ? taskStatus
                                    : 'Pending', // Default to 'Started' if invalid
                                items: [
                                  'Pending',
                                  'Started',
                                  'Continues',
                                  'Finished'
                                ].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Icon(_getStatusIcon(value)),
                                        SizedBox(width: 5),
                                        Text(value),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) async {
                                  if (newValue != null &&
                                      newValue != taskStatus) {
                                    await _firestore
                                        .collection('project_tasks')
                                        .doc(task.id)
                                        .update({'status': newValue});
                                  }
                                },
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getStatusIcon(taskStatus)),
                                  SizedBox(width: 5),
                                  Text(taskStatus),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
