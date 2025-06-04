import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/group/StatusScreens/TaskBasePage.dart';
import 'package:flutter_application_3/group/editTaskProject.dart';
import 'package:flutter_application_3/group/taskDetails.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StartedTasksPage extends TaskBasePage {
  final _auth = FirebaseAuth.instance;
  StartedTasksPage({required String projectId, required bool isManager})
      : super(
          projectId: projectId,
          isManager: isManager,
          taskStatus: 'Started',
        );

  get _firestore => FirebaseFirestore.instance;

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

  // Show edit/delete dialog only for managers
  void _showEditDeleteDialog(
      BuildContext context, DocumentSnapshot task) async {
    // Check if the current user is the project manager
    String currentUserId = _auth.currentUser!.uid;
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

    // Show the edit/delete dialog for the manager
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

  Future<bool> _canViewTaskDetails(String assignedUsername) async {
    // Allow the assigned user or the manager to view task details
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      final currentUsername = userDoc['username'] ?? '';
      if (isManager || currentUsername == assignedUsername) {
        return true;
      }
    } catch (e) {
      // Handle error if needed
    }
    return false;
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Started':
        return Icons.play_arrow;
      case 'Continues':
        return Icons.autorenew;
      case 'Finished':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Started Tasks'),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('project_tasks')
            .where('projectId', isEqualTo: projectId)
            .where('status', isEqualTo: taskStatus)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No started tasks found.'));
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
                    return ListTile(title: Text(task['title']));
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
                        _showEditDeleteDialog(context, task);
                      },
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
