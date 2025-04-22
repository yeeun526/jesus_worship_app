import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = context.read<UserProvider>().uid!;
    return Scaffold(
      appBar: AppBar(title: const Text('출석')),
      body: FutureBuilder<bool>(
        future: FirestoreService().hasAttendedToday(uid),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final did = snap.data!;
          return Center(
            child: did
                ? ElevatedButton(
                    onPressed: () => _showReasonDialog(context, uid),
                    child: const Text('사유 제출'),
                  )
                : ElevatedButton(
                    onPressed: () => FirestoreService().markAttendance(uid),
                    child: const Text('출석'),
                  ),
          );
        },
      ),
    );
  }

  void _showReasonDialog(BuildContext ctx, String uid) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('사유 작성'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () {
              FirestoreService().addReason(uid, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('제출'),
          )
        ],
      ),
    );
  }
}
