// lib/pages/task_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';

class TaskPage extends StatelessWidget {
  const TaskPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = context.read<UserProvider>().uid!;
    return Scaffold(
      appBar: AppBar(title: const Text('과제')),
      body: StreamBuilder<List<Task>>(
        stream: FirestoreService().taskList(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final tasks = snap.data!;
          return ListView(
            children: tasks.map((t) {
              final submitted = t.submissions.containsKey(uid);
              return ListTile(
                title: Text(t.title),
                subtitle: Text('마감: ${t.dueDate.toLocal()}'),
                trailing: submitted
                    ? const Text('제출완료')
                    : ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/task_submit',
                          arguments: t,
                        ),
                        child: const Text('제출'),
                      ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
