import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Management App',
      home: FirebaseAuth.instance.currentUser == null
          ? LoginScreen()
          : TaskListScreen(),
    );
  }
}

// TaskListScreen StatefulWidget
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final CollectionReference _tasksCollection =
      FirebaseFirestore.instance.collection('tasks');

  // Add a task to Firebase
  void _addTask() {
    if (_taskController.text.isNotEmpty) {
      _tasksCollection.add({
        'name': _taskController.text,
        'isCompleted': false,
        'details': _detailsController.text.isNotEmpty
            ? _detailsController.text
            : 'No details provided'
      });
      _taskController.clear();
      _detailsController.clear();
    }
  }

  // Update task completion status
  void _toggleTaskCompletion(DocumentSnapshot task) {
    _tasksCollection.doc(task.id).update({
      'isCompleted': !task['isCompleted'],
    });
  }

  // Delete a task from Firebase
  void _deleteTask(DocumentSnapshot task) {
    _tasksCollection.doc(task.id).delete();
  }

  // Show edit dialog for updating task name and details
  void _showEditTaskDialog(DocumentSnapshot task) {
    final TextEditingController nameController =
        TextEditingController(text: task['name']);
    final TextEditingController detailsController =
        TextEditingController(text: task['details'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Task Name'),
            ),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(labelText: 'Task Details'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _tasksCollection.doc(task.id).update({
                'name': nameController.text,
                'details': detailsController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    labelText: 'Enter a task',
                  ),
                ),
                TextField(
                  controller: _detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Enter task details',
                  ),
                ),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Add Task'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tasksCollection.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((task) {
                    return ListTile(
                      title: Text(
                        task['name'],
                        style: TextStyle(
                          decoration: task['isCompleted']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      subtitle: Text(task['details'] ?? 'No details provided'),
                      leading: Checkbox(
                        value: task['isCompleted'],
                        onChanged: (value) => _toggleTaskCompletion(task),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditTaskDialog(task),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTask(task),
                          ),
                          // Add subtask button
                          IconButton(
                            icon: const Icon(Icons.add_task),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SubtaskManagementScreen(taskId: task.id),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// SubtaskManagementScreen StatefulWidget
class SubtaskManagementScreen extends StatefulWidget {
  final String taskId;
  const SubtaskManagementScreen({super.key, required this.taskId});

  @override
  _SubtaskManagementScreenState createState() =>
      _SubtaskManagementScreenState();
}

class _SubtaskManagementScreenState extends State<SubtaskManagementScreen> {
  final TextEditingController _subtaskController = TextEditingController();
  final CollectionReference _subtasksCollection =
      FirebaseFirestore.instance.collection('tasks');

  // Add a subtask
  void _addSubtask() {
    if (_subtaskController.text.isNotEmpty) {
      _subtasksCollection
          .doc(widget.taskId)
          .collection('subtasks')
          .add({'name': _subtaskController.text});
      _subtaskController.clear();
    }
  }

  // Delete a subtask
  void _deleteSubtask(String subtaskId) {
    _subtasksCollection
        .doc(widget.taskId)
        .collection('subtasks')
        .doc(subtaskId)
        .delete();
  }

  // Update a subtask
  void _updateSubtask(String subtaskId, String newName) {
    _subtasksCollection
        .doc(widget.taskId)
        .collection('subtasks')
        .doc(subtaskId)
        .update({'name': newName});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subtasks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _subtaskController,
              decoration: const InputDecoration(labelText: 'Enter subtask'),
            ),
          ),
          ElevatedButton(
            onPressed: _addSubtask,
            child: const Text('Add Subtask'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _subtasksCollection
                  .doc(widget.taskId)
                  .collection('subtasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((subtask) {
                    return ListTile(
                      title: Text(subtask['name']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              // Open dialog to update subtask
                              _subtaskController.text = subtask['name'];
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Edit Subtask'),
                                  content: TextField(
                                    controller: _subtaskController,
                                    decoration:
                                        const InputDecoration(labelText: 'Subtask Name'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        _updateSubtask(
                                            subtask.id, _subtaskController.text);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteSubtask(subtask.id),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// LoginScreen (unchanged)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => TaskListScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
