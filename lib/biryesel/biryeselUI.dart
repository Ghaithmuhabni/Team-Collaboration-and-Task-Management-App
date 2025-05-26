// biryeselUI.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_3/componants/drawer.dart';
import 'package:intl/intl.dart';
import 'addTask.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // Import AwesomeDialog

class PersonalUsePage extends StatefulWidget {
  @override
  _PersonalUsePageState createState() => _PersonalUsePageState();
}

class _PersonalUsePageState extends State<PersonalUsePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('personal_tasks').doc(taskId).delete();
  }

  void _showEditDeleteDialog(DocumentSnapshot task) {
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
            builder: (context) => AddTaskPage(task: task),
          ),
        );
      },
      btnCancelText: 'Delete',
      btnCancelOnPress: () async {
        await _deleteTask(task.id);
      },
    ).show();
  }

  void _showTaskDetailsBottomSheet(DocumentSnapshot task) {
    DateTime dueDate = (task['date'] as Timestamp).toDate();
    String dueTime = task['time'] ?? 'No time set';
    bool isCompleted = task['completed'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Title: ${task['title']}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Description: ${task['description'] ?? 'No description'}',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16),
                SizedBox(width: 4),
                Text(
                  'Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16),
                SizedBox(width: 4),
                Text(
                  'Due Time: $dueTime',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(isCompleted ? Icons.check_circle : Icons.pending,
                    size: 16),
                SizedBox(width: 4),
                Text(
                  isCompleted ? 'Finished' : 'Not Finished',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _truncateDescription(String description, int maxLength) {
    if (description.length > maxLength) {
      return '${description.substring(0, maxLength)}...';
    }
    return description;
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskPage()),
          );
        },
        backgroundColor: Colors.blue, // Blue color for FAB
        child: Icon(Icons.add, color: Colors.white), // White "+" icon
      ),
      appBar: AppBar(
        title: Text('Personal Tasks'),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241),
      ),
      drawer: AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('personal_tasks')
            .where('uid', isEqualTo: currentUser.uid)
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
              return TaskCard(
                task: task,
                firestore: _firestore,
                auth: _auth,
                showTaskDetailsBottomSheet: _showTaskDetailsBottomSheet,
                showEditDeleteDialog: _showEditDeleteDialog,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class TaskCard extends StatefulWidget {
  final DocumentSnapshot task;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Function(DocumentSnapshot) showTaskDetailsBottomSheet;
  final Function(DocumentSnapshot) showEditDeleteDialog;

  TaskCard({
    required this.task,
    required this.firestore,
    required this.auth,
    required this.showTaskDetailsBottomSheet,
    required this.showEditDeleteDialog,
  });

  @override
  _TaskCardState createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _strikethroughAnimation;
  late Animation<double> _checkboxScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300), // Adjust the duration here
    );

    // Define strikethrough animation
    _strikethroughAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Define checkbox scale animation
    _checkboxScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Add this method to truncate descriptions
  String _truncateDescription(String description, int maxLength) {
    if (description.length > maxLength) {
      return '${description.substring(0, maxLength)}...';
    }
    return description;
  }

  void _toggleCompletion() async {
    bool isCompleted = widget.task['completed'] ?? false;
    if (isCompleted) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    await widget.firestore
        .collection('personal_tasks')
        .doc(widget.task.id)
        .update({'completed': !isCompleted});
  }

  Widget _buildAnimatedText(String text, TextStyle style, bool isCompleted) {
    return AnimatedBuilder(
      animation: _strikethroughAnimation,
      builder: (context, child) {
        double opacity = isCompleted ? _strikethroughAnimation.value : 1.0;
        TextDecoration decoration =
            isCompleted && _strikethroughAnimation.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none;
        return Opacity(
          opacity: opacity,
          child: Text(
            text,
            style: style.copyWith(decoration: decoration),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime dueDate = (widget.task['date'] as Timestamp).toDate();
    String dueTime = widget.task['time'] ?? 'No time set';
    bool isCompleted = widget.task['completed'] ?? false;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Card(
          margin: EdgeInsets.all(10),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isCompleted ? Colors.blue[50] : Colors.white,
          child: InkWell(
            onTap: () {
              widget.showTaskDetailsBottomSheet(widget.task);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom Checkbox with Animation
                  ScaleTransition(
                    scale: _checkboxScaleAnimation,
                    child: GestureDetector(
                      onTap: _toggleCompletion,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCompleted ? Colors.blue : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),

                  // Task Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with Animated Strikethrough
                        _buildAnimatedText(
                          widget.task['title'],
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.grey : Colors.black,
                          ),
                          isCompleted,
                        ),
                        SizedBox(height: 4),

                        // Description (Truncated) with Animated Strikethrough
                        _buildAnimatedText(
                          _truncateDescription(
                              widget.task['description'] ?? 'No description',
                              20),
                          TextStyle(
                            fontSize: 14,
                            color: isCompleted ? Colors.grey : Colors.black54,
                          ),
                          isCompleted,
                        ),
                        SizedBox(height: 4),

                        // Due Date and Time
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Due Time: $dueTime',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Edit/Delete Options
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () {
                      widget.showEditDeleteDialog(widget.task);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
