// projectUI.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/group/groupConversationPage.dart';
import 'package:intl/intl.dart';
import 'addTaskProject.dart';
import 'editTaskProject.dart';
import 'taskDetails.dart';
import 'conversationScreen.dart'; // Import the chat screen
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

  Future<List<Map<String, String>>> _fetchProjectMembers(
      String projectId) async {
    try {
      DocumentSnapshot projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return [];

      String managerId = projectDoc['managerId'];
      String clientId = projectDoc['client'] ?? '';
      List<dynamic> memberIds = projectDoc['members'] ?? [];
      List<Map<String, String>> members = [];
      String currentUserId = _auth.currentUser!.uid;

      // Add the manager
      if (managerId != currentUserId) {
        DocumentSnapshot managerDoc =
            await _firestore.collection('users').doc(managerId).get();
        if (managerDoc.exists) {
          members.add({
            'id': managerId,
            'username': '${managerDoc['username']} (Manager)',
          });
        }
      }

      // Add the client
      if (clientId.isNotEmpty && clientId != currentUserId) {
        DocumentSnapshot clientDoc =
            await _firestore.collection('users').doc(clientId).get();
        if (clientDoc.exists) {
          members.add({
            'id': clientId,
            'username': '${clientDoc['username']} (Client)',
          });
        }
      }

      // Add the members
      for (String memberId in memberIds) {
        if (memberId == currentUserId ||
            memberId == managerId ||
            memberId == clientId) continue;
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          members.add({
            'id': memberId,
            'username': '${userDoc['username']} (Member)',
          });
        }
      }

      return members;
    } catch (e) {
      print("Error fetching project members: $e");
      return [];
    }
  }

  String _getConversationId(String otherUserId) {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, otherUserId];
    ids.sort(); // Sort alphabetically to avoid duplicates
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('projects').doc(widget.projectId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Loading...');
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return Text('Unnamed Project');
            }
            return Text(snapshot.data!['title'] ?? 'Unnamed Project');
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.forum),
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
          ),
          IconButton(
            icon: Icon(Icons.group),
            onPressed: () async {
              List<Map<String, String>> members =
                  await _fetchProjectMembers(widget.projectId);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Project Members'),
                  content: members.isEmpty
                      ? Text('No members found.')
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: members.map((member) {
                              return ListTile(
                                title: Text(member['username']!),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ConversationScreen(
                                        conversationId:
                                            _getConversationId(member['id']!),
                                        otherUserId: member['id']!,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.isManager)
            IconButton(
              icon: Icon(Icons.add),
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
            return Center(child: CircularProgressIndicator());
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
          return ListView(
            children: snapshot.data!.docs.map((task) {
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
                    color: _getPriorityColor(task['priority']),
                    child: ListTile(
                      title: Text(task['title']),
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
            }).toList(),
          );
        },
      ),
    );
  }
}
