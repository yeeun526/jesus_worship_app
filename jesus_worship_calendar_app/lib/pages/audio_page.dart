import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../widgets/permission_widget.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final _searchCtrl = TextEditingController();
  List<String> _results = [];

  void _search() async {
    final res = await FirestoreService().searchAudios(_searchCtrl.text.trim());
    setState(() => _results = res);
  }

  void _add() async {
    final exists =
        await FirestoreService().audioExists(_searchCtrl.text.trim());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 있는 음원입니다')),
      );
    } else {
      await FirestoreService().addAudio(_searchCtrl.text.trim());
      _search();
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('음원 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(labelText: '제목 검색'),
            ),
          ),
          ElevatedButton(onPressed: _search, child: const Text('검색')),
          Expanded(
            child: ListView(
              children: _results.map((t) => ListTile(title: Text(t))).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: PermissionWidget(
        requiredRole: 'admin',
        child: FloatingActionButton(
          onPressed: _add,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
