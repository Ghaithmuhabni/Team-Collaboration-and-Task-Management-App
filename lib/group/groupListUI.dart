// groupUI.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_3/componants/drawer.dart';
import 'package:flutter_application_3/group/groupConversationPage.dart';
import 'addProject.dart';
import 'projectUI.dart';
import 'conversationScreen.dart'; // Import the chat screen

class GroupUIPage extends StatefulWidget {
  @override
  _GroupUIPageState createState() => _GroupUIPageState();
}

class _GroupUIPageState extends State<GroupUIPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _getManagerName(String managerId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(managerId).get();
    return userDoc['username'] ?? 'Unknown';
  }

  Future<List<Map<String, String>>> _fetchProjectMembers(
      List<dynamic> memberIds) async {
    List<Map<String, String>> members = [];
    String currentUserId = _auth.currentUser!.uid;

    for (String memberId in memberIds) {
      if (memberId == currentUserId) continue; // Skip the current user
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        members.add({
          'id': memberId,
          'username': userDoc['username'] ?? 'Unknown',
        });
      }
    }

    return members;
  }

  String _getConversationId(String otherUserId) {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, otherUserId];
    ids.sort(); // Sort alphabetically to avoid duplicates
    return ids.join('_');
  }

  Future<void> _toggleProjectStatus(
      String projectId, String currentStatus) async {
    String newStatus = currentStatus == 'Ongoing' ? 'Finished' : 'Ongoing';
    await _firestore.collection('projects').doc(projectId).update({
      'status': newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: Text('Projects', style: TextStyle(fontSize: 18)),
      ),
      drawer: AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('projects')
            .where(Filter.or(
              Filter('members', arrayContains: currentUser.uid),
              Filter('client', isEqualTo: currentUser.uid),
            ))
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'You are not part of any projects yet.\nPress + to create a new project.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              bool isProjectManager = project['managerId'] == currentUser.uid;
              String projectStatus =
                  project['status'] ?? 'Ongoing'; // Default status

              return FutureBuilder<String>(
                future: _getManagerName(project['managerId']),
                builder: (context, managerSnapshot) {
                  if (!managerSnapshot.hasData)
                    return CircularProgressIndicator();

                  return FutureBuilder<List<Map<String, String>>>(
                    future: _fetchProjectMembers(project['members']),
                    builder: (context, membersSnapshot) {
                      if (!membersSnapshot.hasData)
                        return CircularProgressIndicator();

                      return Card(
                        margin: EdgeInsets.all(10),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            project['title'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(project['description']),
                              Text(
                                'Manager: ${managerSnapshot.data}',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                              Text(
                                'Status: $projectStatus',
                                style: TextStyle(
                                  color: projectStatus == 'Finished'
                                      ? Colors.green
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Conversation Icon
                              IconButton(
                                icon: Icon(Icons.forum),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GroupConversationPage(
                                        projectId: project.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Group Icon (Members List)
                              IconButton(
                                icon: Icon(Icons.group),
                                onPressed: () async {
                                  List<Map<String, String>> members =
                                      await _fetchProjectMembers(
                                          project['members']);
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Project Members'),
                                      content: members.isEmpty
                                          ? Text('No members found.')
                                          : SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: members.map((member) {
                                                  return ListTile(
                                                    title: Text(
                                                        member['username']!),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ConversationScreen(
                                                            conversationId:
                                                                _getConversationId(
                                                                    member[
                                                                        'id']!),
                                                            otherUserId:
                                                                member['id']!,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Task Icon (Only for Managers)
                              IconButton(
                                icon: Icon(
                                  Icons.task,
                                  color: projectStatus == 'Finished'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                onPressed: isProjectManager
                                    ? () async {
                                        await _toggleProjectStatus(
                                            project.id, projectStatus);
                                        setState(() {}); // Refresh UI
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProjectUI(
                                  projectId: project.id,
                                  isManager: isProjectManager,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddProjectPage()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
