// UseCasesPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_3/componants/drawer.dart';
import 'login.dart';
import '../biryesel/biryeselUI.dart'; // Import the Personal Use UI
import '../group/groupListUI.dart'; // Import the Group UI
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UseCasesPage extends StatefulWidget {
  final String username;

  UseCasesPage({required this.username});

  @override
  _UseCasesPageState createState() => _UseCasesPageState();
}

class _UseCasesPageState extends State<UseCasesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _personalTasks = [];

  Future<void> _fetchTodayTasks() async {
    try {
      DateTime now = DateTime.now();
      Timestamp todayStart =
          Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      Timestamp tomorrowStart =
          Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1));

      String currentUserId = _auth.currentUser!.uid;

      QuerySnapshot snapshot = await _firestore
          .collection('personal_tasks')
          .where('uid', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThan: tomorrowStart)
          .get();

      setState(() {
        _personalTasks = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });

      // Debugging: Print the fetched tasks
      print('Fetched tasks: $_personalTasks');
    } catch (e) {
      print('Error fetching tasks: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTodayTasks(); // Fetch tasks when the page loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Use Case'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 4, 135, 241),
      ),
      drawer: AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Text(
              'Hello ${widget.username}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Use Case Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PersonalUsePage()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 48, color: Colors.blue),
                            SizedBox(height: 8),
                            Text(
                              'Individual Use',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => GroupUIPage()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 48, color: Colors.blue),
                            SizedBox(height: 8),
                            Text(
                              'Group Use',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Personal Tasks Due Today
            Text(
              'Personal Tasks Due Today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (_personalTasks.isEmpty)
              Center(
                child: Text(
                  'You don\'t have any tasks for today.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _personalTasks.length,
                  itemBuilder: (context, index) {
                    var task = _personalTasks[index];
                    DateTime dueDate = (task['date'] as Timestamp).toDate();
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(task['title']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task['description'] != null &&
                                task['description'].isNotEmpty)
                              Text(task['description']),
                            Text(
                              '${DateFormat('d MMM yyyy').format(dueDate)} at ${task['time']}',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chat_bubble_outline),
                              onPressed: () {
                                // Handle chat action
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.photo_album_outlined),
                              onPressed: () {
                                // Handle attachment action
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
