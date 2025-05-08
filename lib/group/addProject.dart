// addProject.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProjectPage extends StatefulWidget {
  @override
  _AddProjectPageState createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clientSearchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, String>> _selectedMembers = [];
  Map<String, String>? _selectedClient;
  List<Map<String, String>> _searchResults = [];
  List<Map<String, String>> _clientSearchResults = [];
  bool _isAddingClient = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser.uid;
      });
    }
  }

  Future<void> _createProject() async {
    if (_currentUserId.isEmpty) return;

    try {
      await _firestore.collection('projects').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'managerId': _currentUserId,
        'members': [_currentUserId, ..._selectedMembers.map((m) => m['uid']!)],
        'client': _selectedClient != null ? _selectedClient!['uid'] : null,
        'clientName': _selectedClient != null ? _selectedClient!['name'] : null,
        'status': 'Ongoing', // Add default project status
        'createdAt': FieldValue.serverTimestamp(), // Add creation timestamp
      });

      Navigator.pop(context); // Navigate back after creating the project
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating project: $e')),
      );
    }
  }

  void _searchUsers(String query, {bool isClientSearch = false}) async {
    if (query.isEmpty) {
      setState(() {
        if (isClientSearch) {
          _clientSearchResults.clear();
        } else {
          _searchResults.clear();
        }
      });
      return;
    }

    QuerySnapshot usersSnapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: query + '\uf8ff')
        .get();

    QuerySnapshot emailSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: query)
        .get();

    Set<Map<String, String>> results = {};

    for (var doc in usersSnapshot.docs) {
      results.add({"uid": doc.id, "name": doc['username']});
    }
    for (var doc in emailSnapshot.docs) {
      results.add({"uid": doc.id, "name": doc['username']});
    }

    // Filter out the current user from the results
    results.removeWhere((user) => user['uid'] == _currentUserId);

    setState(() {
      if (isClientSearch) {
        _clientSearchResults = results.toList();
      } else {
        _searchResults = results
            .where((user) =>
                !_selectedMembers.any((m) => m['uid'] == user['uid']) &&
                (_selectedClient == null ||
                    _selectedClient!['uid'] != user['uid']))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Project')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Project Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Project Description'),
            ),
            CheckboxListTile(
              title: Text("Add Client?"),
              value: _isAddingClient,
              onChanged: (value) {
                setState(() {
                  _isAddingClient = value!;
                  if (!value) {
                    _selectedClient = null;
                    _clientSearchController.clear();
                  }
                });
              },
            ),
            if (_isAddingClient)
              Column(
                children: [
                  TextField(
                    controller: _clientSearchController,
                    decoration: InputDecoration(labelText: 'Search Client'),
                    onChanged: (value) =>
                        _searchUsers(value, isClientSearch: true),
                  ),
                  if (_clientSearchResults.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _clientSearchResults.length,
                        itemBuilder: (context, index) {
                          var user = _clientSearchResults[index];
                          return ListTile(
                            title: Text(user['name']!),
                            onTap: () {
                              setState(() {
                                _selectedClient = user;
                                _clientSearchResults.clear();
                                _clientSearchController.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  if (_selectedClient != null)
                    Chip(
                      label: Text(_selectedClient!['name']!),
                      backgroundColor: Colors.orange[200],
                      onDeleted: () {
                        setState(() {
                          _selectedClient = null;
                        });
                      },
                    ),
                ],
              ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(labelText: 'Search Team Members'),
              onChanged: _searchUsers,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  var user = _searchResults[index];
                  return ListTile(
                    title: Text(user['name']!),
                    onTap: () {
                      setState(() {
                        _selectedMembers.add(user);
                        _searchResults.clear();
                        _searchController.clear();
                      });
                    },
                  );
                },
              ),
            ),
            Wrap(
              children: _selectedMembers
                  .map((member) => Chip(
                        label: Text(member['name']!),
                        onDeleted: () {
                          setState(() {
                            _selectedMembers.remove(member);
                          });
                        },
                      ))
                  .toList(),
            ),
            ElevatedButton(
              onPressed: _createProject,
              child: Text('Create Project'),
            ),
          ],
        ),
      ),
    );
  }
}
