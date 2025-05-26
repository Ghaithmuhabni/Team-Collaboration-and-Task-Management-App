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
        _dueTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: const Color.fromARGB(255, 4, 135, 241),
        ),
      );
      return;
    }

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

    Navigator.pop(context); // Return to the project page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Task',
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
                    TextField(
                      controller: _taskTitleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _taskDescriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Task Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => ListView(
                            children: _teamMembers.map((member) {
                              return ListTile(
                                title: Text(member['name']!),
                                onTap: () {
                                  setState(() {
                                    _assignedToController.text =
                                        member['name']!;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                      child: IgnorePointer(
                        child: TextField(
                          controller: _assignedToController,
                          decoration: InputDecoration(
                            labelText: 'Assigned To',
                            hintText: 'Select a team member',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    InkWell(
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
                      child: IgnorePointer(
                        child: TextField(
                          controller: _dueDateController,
                          decoration: InputDecoration(
                            labelText: 'Due Date',
                            hintText: 'Select Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _dueTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _dueTime = pickedTime;
                            _dueTimeController.text =
                                pickedTime.format(context);
                          });
                        }
                      },
                      child: IgnorePointer(
                        child: TextField(
                          controller: _dueTimeController,
                          decoration: InputDecoration(
                            labelText: 'Due Time',
                            hintText: 'Select Time',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 4, 135, 241),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 4, 135, 241),
                          ),
                        ),
                      ),
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
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 4, 135, 241),
                      ),
                      child: Text(
                        'Update Task',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
