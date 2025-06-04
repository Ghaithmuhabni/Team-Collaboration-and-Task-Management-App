import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/group/editTaskProject.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_dialog/awesome_dialog.dart';


abstract class TaskBasePage extends StatelessWidget {
  final String projectId;
  final bool isManager;
  final String taskStatus;

  TaskBasePage({
    required this.projectId,
    required this.isManager,
    required this.taskStatus,
  });

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get priority color based on task priority
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red[400]!;
      case 'Normal':
        return Colors.orange[500]!;
      case 'Low':
        return Colors.green[300]!;
      default:
        return Colors.grey[200]!;
    }
  }

  // Get status icon based on task status
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

  // Show edit/delete dialog
  void _showEditDeleteDialog(BuildContext context, DocumentSnapshot task) {
    if (!isManager) {
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
    DocumentSnapshot currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    String currentUsername = currentUserDoc['username'] ?? 'Unknown';
    DocumentSnapshot projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    String clientId = projectDoc['client'] ?? '';
    return isManager ||
        currentUserId == clientId ||
        currentUsername == assignedTo;
  }
}