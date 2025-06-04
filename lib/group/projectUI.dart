// projectUI.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_3/group/StatusScreens/continuesTasks.dart';
import 'package:flutter_application_3/group/StatusScreens/finishedTask.dart';
import 'package:flutter_application_3/group/StatusScreens/newTasks.dart';
import 'package:flutter_application_3/group/addTaskProject.dart';
import 'package:flutter_application_3/group/groupConversationPage.dart';
import 'conversationScreen.dart';
import 'package:flutter_application_3/group/StatusScreens/startedTask.dart';

class ProjectUI extends StatefulWidget {
  final String projectId;
  final bool isManager;

  ProjectUI({required this.projectId, required this.isManager});

  @override
  _ProjectUIState createState() => _ProjectUIState();
}

class _ProjectUIState extends State<ProjectUI> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Map<String, String>>> _fetchProjectMembers(
      List<dynamic> memberIds, String projectId) async {
    List<Map<String, String>> members = [];
    String currentUserId = _auth.currentUser!.uid; // Get the current user's ID

    try {
      DocumentSnapshot projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return [];

      String managerId = projectDoc['managerId'];
      String clientId = projectDoc['client'] ?? '';

      // Add the manager if they are not the current user
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

      // Add the client if they are not the current user
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

      // Add other members if they are not the current user
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

  String _getStatusForQuery(String title) {
    switch (title.split(' ')[0]) {
      case 'New':
        return 'Pending'; // Match Firestore's actual status name
      case 'Started':
        return 'Started';
      case 'Continuing':
        return 'Continues'; // Match Firestore's actual status name
      case 'Finished':
        return 'Finished';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Project Tasks'),
        backgroundColor: Colors.blue[800],
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('project_conversation')
                .doc(widget.projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return IconButton(
                  icon: Icon(Icons.forum),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupConversationPage(
                          projectId: widget.projectId,
                        ),
                      ),
                    );
                  },
                );
              }
              Map<String, dynamic>? data =
                  snapshot.data?.data() as Map<String, dynamic>?;
              String currentUserId = _auth.currentUser!.uid;
              Timestamp lastMessageTimestamp =
                  data?['lastMessageTimestamp'] as Timestamp? ??
                      Timestamp(0, 0);
              Timestamp lastSeenTimestamp =
                  (data?['lastSeen'] as Map<String, dynamic>? ??
                          {})[currentUserId] as Timestamp? ??
                      Timestamp(0, 0);
              bool hasUnreadMessages =
                  lastMessageTimestamp.compareTo(lastSeenTimestamp) > 0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.forum),
                    onPressed: () async {
                      await _firestore
                          .collection('project_conversation')
                          .doc(widget.projectId)
                          .update({
                        'lastSeen.$currentUserId': FieldValue.serverTimestamp(),
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupConversationPage(
                            projectId: widget.projectId,
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
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints:
                            BoxConstraints(minWidth: 12, minHeight: 12),
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
            icon: Icon(Icons.group),
            onPressed: () async {
              // Fetch the project document to get the memberIds list
              DocumentSnapshot projectDoc = await _firestore
                  .collection('projects')
                  .doc(widget.projectId)
                  .get();
              List<dynamic> memberIds = projectDoc['members'] ?? [];
              List<Map<String, String>> members =
                  await _fetchProjectMembers(memberIds, widget.projectId);
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
                                title: Text(member['username']!),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ConversationScreen(
                                        conversationId: widget.projectId,
                                        otherUserId: member['id']!,
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
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTaskCard(
              context,
              'New Tasks',
              Icons.new_releases,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NewTaskPage(projectId: widget.projectId),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            _buildTaskCard(
              context,
              'Started Tasks',
              Icons.play_arrow,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StartedTasksPage(
                      projectId: widget.projectId,
                      isManager: widget.isManager,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            _buildTaskCard(
              context,
              'Continuing Tasks',
              Icons.timelapse,
              Colors.green,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContinuedTasksPage(
                      projectId: widget.projectId,
                      isManager: widget.isManager,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            _buildTaskCard(
              context,
              'Finished Tasks',
              Icons.check_circle,
              Colors.red,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FinishedTasksPage(
                        projectId: widget.projectId,
                        isManager: widget.isManager),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isManager
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTaskProjectPage(
                      projectId: widget.projectId,
                    ),
                  ),
                );
              },
              backgroundColor:
                  const Color.fromARGB(255, 4, 135, 241), // Blue theme
              child: Icon(Icons.add, color: Colors.white), // White "+" icon
            )
          : null,
    );
  }

  Widget _buildTaskCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 100,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('project_tasks')
                          .where('projectId', isEqualTo: widget.projectId)
                          .where('status', isEqualTo: _getStatusForQuery(title))
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Text('Loading...');
                        }
                        int count = snapshot.data!.docs.length;
                        return Text('$count tasks');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
