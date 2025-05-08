// biryeselUI.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_3/componants/drawer.dart';
import 'addTask.dart';
import 'package:intl/intl.dart';

class PersonalUsePage extends StatefulWidget {
  @override
  _PersonalUsePageState createState() => _PersonalUsePageState();
}

class _PersonalUsePageState extends State<PersonalUsePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initialize FirebaseAuth
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Future<void> _addTask() async {
    if (_titleController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      // Show error if fields are empty
      return;
    }
    await _firestore.collection('personal_tasks').add({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'date': _selectedDate,
      'time': _selectedTime?.format(context),
      'completed': false,
    });
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  Future<void> _editTask(DocumentSnapshot task) async {
    // Implement edit functionality
  }

  Future<void> _deleteTask(DocumentSnapshot task) async {
    await _firestore.collection('personal_tasks').doc(task.id).delete();
  }

  void _showEditDeleteDialog(DocumentSnapshot task) {
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
                  builder: (context) => AddTaskPage(task: task),
                ),
              );
            },
            child: Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              _deleteTask(task);
              Navigator.pop(context);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser; // Get the current user
    if (currentUser == null)
      return CircularProgressIndicator(); // Ensure user is logged in
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskPage()),
          );
        },
        child: Icon(Icons.add),
      ),
      appBar: AppBar(
        title: Text('Personal Tasks'),
      ),
      drawer: AppDrawer(),
      body: StreamBuilder(
        stream: _firestore
            .collection('personal_tasks')
            .where('uid', isEqualTo: currentUser.uid) // Filter by user UID
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          return ListView(
            children: snapshot.data!.docs.map((task) {
              DateTime date = (task['date'] as Timestamp).toDate();
              String formattedDate = DateFormat('yyyy-MM-dd').format(date);
              return Card(
                margin: EdgeInsets.all(10),
                child: ListTile(
                  title: Text(task['title']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task['description']),
                      Text('Date: $formattedDate'),
                      Text('Time: ${task['time']}'),
                    ],
                  ),
                  trailing: Checkbox(
                    value: task['completed'],
                    onChanged: (bool? value) {
                      _firestore
                          .collection('personal_tasks')
                          .doc(task.id)
                          .update({
                        'completed': value,
                      });
                    },
                  ),
                  onLongPress: () => _showEditDeleteDialog(task),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
