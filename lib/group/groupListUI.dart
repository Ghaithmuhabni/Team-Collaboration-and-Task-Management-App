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
      List<dynamic> memberIds, String projectId) async {
    List<Map<String, String>> members = [];
    String currentUserId = _auth.currentUser!.uid;
    try {
      DocumentSnapshot projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return [];
      String managerId = projectDoc['managerId'];
      String clientId = projectDoc['client'] ?? '';
      if (managerId != currentUserId) {
        DocumentSnapshot managerDoc =
            await _firestore.collection('users').doc(managerId).get();
        if (managerDoc.exists) {
          members.add({
            'id': managerId,
            'username': '${managerDoc['username']} (Manager)',
          });
        }
      }
      if (clientId.isNotEmpty && clientId != currentUserId) {
        DocumentSnapshot clientDoc =
            await _firestore.collection('users').doc(clientId).get();
        if (clientDoc.exists) {
          members.add({
            'id': clientId,
            'username': '${clientDoc['username']} (Client)',
          });
        }
      }
      for (String memberId in memberIds) {
        if (memberId == currentUserId ||
            memberId == managerId ||
            memberId == clientId) continue;
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          members.add({
            'id': memberId,
            'username': '${userDoc['username']} (Member)',
          });
        }
      }
    } catch (e) {
      print("Error fetching project members: $e");
    }
    return members;
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Projects',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
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
                    'You are not part of any projects yet.\nPress + to create a new project.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var project = snapshot.data!.docs[index];
              bool isProjectManager = project['managerId'] == currentUser.uid;
              String projectStatus = project['status'] ?? 'Ongoing';

              return FutureBuilder<String>(
                future: _getManagerName(project['managerId']),
                builder: (context, managerSnapshot) {
                  if (!managerSnapshot.hasData) {
                    return CircularProgressIndicator();
                  }
                  return FutureBuilder<List<Map<String, String>>>(
                    future:
                        _fetchProjectMembers(project['members'], project.id),
                    builder: (context, membersSnapshot) {
                      if (!membersSnapshot.hasData) {
                        return CircularProgressIndicator();
                      }
                      return Card(
                        margin: EdgeInsets.all(10),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.blue[50], // Light blue card background
                        child: ListTile(
                          title: Text(
                            project['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800], // Dark blue text
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project['description'],
                                style: TextStyle(color: Colors.black54),
                              ),
                              Text(
                                'Manager: ${managerSnapshot.data}',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.blue[700], // Blue text
                                ),
                              ),
                              Text(
                                'Status: $projectStatus',
                                style: TextStyle(
                                  color: projectStatus == 'Finished'
                                      ? Colors.green
                                      : Colors.blue[900], // Blue text
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                stream: _firestore
                                    .collection('project_conversation')
                                    .doc(project.id)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData ||
                                      !snapshot.data!.exists) {
                                    return IconButton(
                                      icon: Icon(Icons.forum,
                                          color: Colors.blue[800]),
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
                                    );
                                  }
                                  Map<String, dynamic>? data = snapshot.data
                                      ?.data() as Map<String, dynamic>?;
                                  String currentUserId = _auth.currentUser!.uid;
                                  Timestamp lastMessageTimestamp =
                                      data?['lastMessageTimestamp']
                                              as Timestamp? ??
                                          Timestamp(0, 0);
                                  Timestamp lastSeenTimestamp = (data?[
                                                  'lastSeen']
                                              as Map<String, dynamic>? ??
                                          {})[currentUserId] as Timestamp? ??
                                      Timestamp(0, 0);
                                  bool hasUnreadMessages = lastMessageTimestamp
                                          .compareTo(lastSeenTimestamp) >
                                      0;
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.forum,
                                            color: Colors.blue[800]),
                                        onPressed: () async {
                                          await _firestore
                                              .collection(
                                                  'project_conversation')
                                              .doc(project.id)
                                              .update({
                                            'lastSeen.$currentUserId':
                                                FieldValue.serverTimestamp(),
                                          });
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
                                      if (hasUnreadMessages)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            constraints: BoxConstraints(
                                                minWidth: 12, minHeight: 12),
                                            child: Text(
                                              '!',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              IconButton(
                                icon:
                                    Icon(Icons.group, color: Colors.blue[800]),
                                onPressed: () async {
                                  List<Map<String, String>> members =
                                      await _fetchProjectMembers(
                                          project['members'], project.id);
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
                                                                project.id,
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
                              IconButton(
                                icon: Icon(
                                  Icons.task,
                                  color: projectStatus == 'Finished'
                                      ? Colors.green
                                      : Colors.blue[800],
                                ),
                                onPressed: isProjectManager
                                    ? () async {
                                        await _firestore
                                            .collection('projects')
                                            .doc(project.id)
                                            .update({
                                          'status': projectStatus == 'Ongoing'
                                              ? 'Finished'
                                              : 'Ongoing',
                                        });
                                        setState(() {});
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
        backgroundColor: const Color.fromARGB(255, 4, 135, 241), // Blue theme
        child: Icon(Icons.add, color: Colors.white), // White "+" icon
      ),
    );
  }
}
