// projectUI.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/group/groupConversationPage.dart';
import 'package:intl/intl.dart';
import 'addTaskProject.dart';
import 'editTaskProject.dart';
import 'taskDetails.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectUI extends StatefulWidget {
  final String projectId;
  final bool isManager;

  ProjectUI({required this.projectId, required this.isManager});

  @override
  _ProjectUIState createState() => _ProjectUIState();
}

class _ProjectUIState extends State<ProjectUI> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch the project name from Firestore
  Future<String> _getProjectName(String projectId) async {
    DocumentSnapshot projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    return projectDoc['title'] ?? 'Unnamed Project';
  }

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

  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('project_tasks').doc(taskId).delete();
  }

  void _showEditDeleteDialog(DocumentSnapshot task) {
    if (!widget.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only the project manager can edit or delete tasks.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit or Delete Task'),
        content: Text('Would you like to edit or delete this task?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
            child: Text('Edit'),
          ),
          TextButton(
            onPressed: () async {
              await _deleteTask(task.id);
              Navigator.pop(context);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

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

  Future<bool> _canViewTaskDetails(String assignedTo) async {
    String currentUserId = _auth.currentUser!.uid;
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    String currentUsername = currentUserDoc['username'] ?? 'Unknown';
    DocumentSnapshot projectDoc =
        await _firestore.collection('projects').doc(widget.projectId).get();
    String clientId = projectDoc['client'] ?? '';
    return widget.isManager ||
        currentUserId == clientId ||
        currentUsername == assignedTo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _getProjectName(widget.projectId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Loading...'); // Show loading while fetching the name
            }
            if (snapshot.hasError) {
              return Text('Error'); // Handle errors gracefully
            }
            return Text(
              snapshot.data ??
                  'Unnamed Project', // Use the fetched project name
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white), // White text for better contrast
            );
          },
        ),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('project_conversation')
                .doc(widget.projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return IconButton(
                  icon: Icon(Icons.forum, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupConversationPage(
                          projectId: widget.projectId,
                        ),
                      ),
                    );
                  },
                );
              }
              Map<String, dynamic>? data =
                  snapshot.data?.data() as Map<String, dynamic>?;
              String currentUserId = _auth.currentUser!.uid;
              Timestamp lastMessageTimestamp =
                  data?['lastMessageTimestamp'] as Timestamp? ??
                      Timestamp(0, 0);
              Timestamp lastSeenTimestamp =
                  (data?['lastSeen'] as Map<String, dynamic>? ??
                          {})[currentUserId] as Timestamp? ??
                      Timestamp(0, 0);
              bool hasUnreadMessages =
                  lastMessageTimestamp.compareTo(lastSeenTimestamp) > 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.forum, color: Colors.white),
                    onPressed: () async {
                      await _firestore
                          .collection('project_conversation')
                          .doc(widget.projectId)
                          .update({
                        'lastSeen.$currentUserId': FieldValue.serverTimestamp(),
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupConversationPage(
                            projectId: widget.projectId,
                          ),
                        ),
                      );
                    },
                  ),
                  if (hasUnreadMessages)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints:
                            BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (widget.isManager)
            IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTaskProjectPage(
                      projectId: widget.projectId,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('project_tasks')
            .where('projectId', isEqualTo: widget.projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color.fromARGB(255, 4, 135, 241), // Blue theme
                ),
                strokeWidth: 3, // Smaller stroke width
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
                    'No tasks found.\nPress + to create a new task.',
                    textAlign: TextAlign.center,
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
              String taskStatus = task['status'] ?? 'Started';
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
                  return Card(
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
                                  color:
                                      isCurrentUserAssigned ? Colors.red : null,
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
                              value: taskStatus,
                              items: ['Started', 'Continues', 'Finished']
                                  .map((String value) {
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
                                if (newValue != null) {
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
                        _showEditDeleteDialog(task);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.isManager) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTaskProjectPage(
                  projectId: widget.projectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only the project manager can add tasks.'),
              ),
            );
          }
        },
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
        child: Icon(Icons.add, color: Colors.white), // White "+" icon
      ),
    );
  }
}
