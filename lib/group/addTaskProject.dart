// addTaskProject.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddTaskProjectPage extends StatefulWidget {
  final String projectId;

  AddTaskProjectPage({required this.projectId});

  @override
  _AddTaskProjectPageState createState() => _AddTaskProjectPageState();
}

class _AddTaskProjectPageState extends State<AddTaskProjectPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
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
  PlatformFile? _file;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      DocumentSnapshot projectSnapshot =
          await _firestore.collection('projects').doc(widget.projectId).get();
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

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _file = result.files.first;
      });
      print("File picked: ${_file!.name}");
    } else {
      print("No file selected.");
    }
  }

  Future<String?> _uploadFile(String taskId) async {
    if (_file == null || _file!.bytes == null) {
      print("No file selected or file data is invalid.");
      return null;
    }

    try {
      Reference storageRef =
          _storage.ref().child('task_files/$taskId/${_file!.name}');
      UploadTask uploadTask = storageRef.putData(_file!.bytes!);
      TaskSnapshot snapshot = await uploadTask;
      String fileUrl = await snapshot.ref.getDownloadURL();
      print("File uploaded successfully. Download URL: $fileUrl");
      return fileUrl;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  Future<void> _createTask() async {
    if (_taskTitleController.text.isEmpty ||
        _assignedToController.text.isEmpty ||
        _dueDate == null ||
        _dueTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields.')),
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

    String taskId = _firestore.collection('project_tasks').doc().id;

    // Upload file and get download URL
    String? fileUrl = await _uploadFile(taskId);

    // Save task data to Firestore
    await _firestore.collection('project_tasks').doc(taskId).set({
      'title': _taskTitleController.text,
      'description': _taskDescriptionController.text,
      'assignedTo': _assignedToController.text,
      'dueDate': combinedDateTime.toIso8601String(),
      'priority': _priority,
      'status': 'Started',
      'projectId': widget.projectId,
      'fileUrl': fileUrl,
    });

    Navigator.pop(context); // Go back to the project page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
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
                  initialDate: DateTime.now(),
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
                  initialTime: TimeOfDay.now(),
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
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickFile,
                    child:
                        Text(_file == null ? 'Upload File' : 'File Selected'),
                  ),
                ),
                SizedBox(width: 10),
                if (_file != null)
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _file = null;
                      });
                    },
                  ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createTask,
              child: Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}