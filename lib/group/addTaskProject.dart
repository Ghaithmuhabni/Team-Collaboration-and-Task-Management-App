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
      return await snapshot.ref.getDownloadURL();
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
        title: Text(
          'Add Task',
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
                          initialTime: TimeOfDay.now(),
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
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _pickFile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 4, 135, 241),
                            ),
                            child: Text(
                              _file == null ? 'Upload File' : 'File Selected',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        if (_file != null)
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 4, 135, 241),
                      ),
                      child: Text(
                        'Create Task',
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
