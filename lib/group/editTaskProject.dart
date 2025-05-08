// editTaskProject.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditTaskProjectPage extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  EditTaskProjectPage({required this.taskId, required this.taskData});

  @override
  _EditTaskProjectPageState createState() => _EditTaskProjectPageState();
}

class _EditTaskProjectPageState extends State<EditTaskProjectPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();
  final TextEditingController _assignedToController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _dueTimeController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _priority = 'Normal';
  List<Map<String, String>> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTaskData();
      _loadTeamMembers();
    });
  }

  void _loadTaskData() {
    _taskTitleController.text = widget.taskData['title'];
    _taskDescriptionController.text = widget.taskData['description'];
    _assignedToController.text = widget.taskData['assignedTo'] ?? '';
    _dueDate = DateTime.parse(widget.taskData['dueDate']);
    _dueTime = TimeOfDay.fromDateTime(_dueDate!);
    _priority = widget.taskData['priority'] ?? 'Normal';
    _dueDateController.text = DateFormat('yyyy-MM-dd').format(_dueDate!);
    _dueTimeController.text = _dueTime!.format(context);
  }

  Future<void> _loadTeamMembers() async {
    try {
      DocumentSnapshot projectSnapshot = await _firestore
          .collection('projects')
          .doc(widget.taskData['projectId'])
          .get();
      if (projectSnapshot.exists) {
        List<dynamic> members = projectSnapshot['members'] ?? [];
        setState(() {
          _teamMembers = members.map((memberId) {
            return {"uid": memberId as String, "name": "Loading..."};
          }).toList();
        });
        for (int i = 0; i < _teamMembers.length; i++) {
          String memberId = _teamMembers[i]['uid']!;
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            setState(() {
              _teamMembers[i]["name"] = userDoc["username"];
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching team members: $e");
    }
  }

  Future<void> _updateTask() async {
    if (_taskTitleController.text.isEmpty ||
        _assignedToController.text.isEmpty ||
        _dueDate == null ||
        _dueTime == null) return;

    DateTime combinedDateTime = DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _dueTime!.hour,
      _dueTime!.minute,
    );

    await _firestore.collection('project_tasks').doc(widget.taskId).update({
      'title': _taskTitleController.text,
      'description': _taskDescriptionController.text,
      'assignedTo': _assignedToController.text,
      'dueDate': combinedDateTime.toIso8601String(),
      'priority': _priority,
    });

    Navigator.pop(context); // العودة إلى صفحة المشروع
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _taskTitleController,
              decoration: InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _taskDescriptionController,
              decoration: InputDecoration(labelText: 'Task Description'),
            ),
            TextField(
              controller: _assignedToController,
              readOnly: true,
              decoration: InputDecoration(
                  labelText: 'Assigned To', hintText: 'Select a team member'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => ListView(
                    children: _teamMembers.map((member) {
                      return ListTile(
                        title: Text(member['name']!),
                        onTap: () {
                          setState(() {
                            _assignedToController.text = member['name']!;
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            TextFormField(
              controller: _dueDateController,
              readOnly: true,
              decoration: InputDecoration(
                  labelText: 'Due Date', hintText: 'Select Date'),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _dueDate = pickedDate;
                    _dueDateController.text =
                        DateFormat('yyyy-MM-dd').format(pickedDate);
                  });
                }
              },
            ),
            TextFormField(
              controller: _dueTimeController,
              readOnly: true,
              decoration: InputDecoration(
                  labelText: 'Due Time', hintText: 'Select Time'),
              onTap: () async {
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _dueTime ?? TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    _dueTime = pickedTime;
                    _dueTimeController.text = pickedTime.format(context);
                  });
                }
              },
            ),
            DropdownButton<String>(
              value: _priority,
              items: ['Low', 'Normal', 'High'].map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(priority),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _priority = value;
                  });
                }
              },
            ),
            ElevatedButton(
              onPressed: _updateTask,
              child: Text('Update Task'),
            ),
          ],
        ),
      ),
    );
  }
}
