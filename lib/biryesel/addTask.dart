import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddTaskPage extends StatefulWidget {
  final DocumentSnapshot? task;

  AddTaskPage({this.task});

  @override
  _AddTaskPageState createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!['title'];
      _descriptionController.text = widget.task!['description'];
      _selectedDate = widget.task!['date'].toDate();
      _selectedTime = TimeOfDay.fromDateTime(widget.task!['date'].toDate());
    }
  }

  Future<void> _addOrUpdateTask() async {
    if (_titleController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      // Show error if fields are empty
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (widget.task == null) {
      await _firestore.collection('personal_tasks').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'date': _selectedDate,
        'time': _selectedTime?.format(context),
        'completed': false,
        'uid': currentUser.uid,
      });
    } else {
      await _firestore
          .collection('personal_tasks')
          .doc(widget.task!.id)
          .update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'date': _selectedDate,
        'time': _selectedTime?.format(context),
      });
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Update Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date',
                hintText: _selectedDate != null
                    ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                    : 'Select Date',
              ),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(), // Prevent selecting past dates
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _selectedDate = pickedDate;
                  });
                }
              },
            ),
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Time',
                hintText: _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Select Time',
              ),
              onTap: () async {
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime ?? TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    _selectedTime = pickedTime;
                  });
                }
              },
            ),
            ElevatedButton(
              onPressed: _addOrUpdateTask,
              child: Text(widget.task == null ? 'Add Task' : 'Update Task'),
            ),
          ],
        ),
      ),
    );
  }
}
