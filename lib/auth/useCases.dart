import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../componants/drawer.dart'; // Import the AppDrawer
import '../biryesel/biryeselUI.dart'; // Import the Personal Use UI
import '../group/groupListUI.dart'; // Import the Group UI

class UseCasesPage extends StatefulWidget {
  final String username;
  const UseCasesPage({required this.username, Key? key}) : super(key: key);

  @override
  State<UseCasesPage> createState() => _UseCasesPageState();
}

class _UseCasesPageState extends State<UseCasesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getAllTasksStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    return _firestore
        .collection('personal_tasks')
        .where('uid', isEqualTo: user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Use Case'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        backgroundColor: const Color.fromARGB(255, 4, 135, 241),
      ),
      drawer: AppDrawer(), // Add the AppDrawer here
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Text(
              'Hello ${widget.username}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Use Case Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildUseCaseCard(
                  icon: Icons.person,
                  title: 'Individual Use',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PersonalUsePage()),
                    );
                  },
                ),
                const SizedBox(width: 16),
                _buildUseCaseCard(
                  icon: Icons.people,
                  title: 'Group Use',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GroupUIPage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tasks List Title
            const Text(
              'All Tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Tasks List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getAllTasksStream(),
                builder: (context, snapshot) {
                  // Error Handling
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  // Loading State
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Empty State
                  if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No tasks found'));
                  }

                  // Success State - Show ALL tasks
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // Debug print to verify we're getting data
                      debugPrint('Task Data: $data');

                      return Card(
                        child: ListTile(
                          title: Text(data['title'] ?? 'No Title'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['description'] != null &&
                                  data['description'].isNotEmpty)
                                Text(data['description']),
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${data['date'] != null ? DateFormat('MMM d, yyyy').format((data['date'] as Timestamp).toDate()) : 'No date'}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Method to Build Use Case Cards
  Widget _buildUseCaseCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Colors.blue),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
