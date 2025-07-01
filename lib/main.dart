import 'package:flutter/material.dart';

void main() {
  runApp(const MagicChecksApp());
}

class MagicChecksApp extends StatelessWidget {
  const MagicChecksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MagicChecks',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ChecklistScreen(),
    );
  }
}

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // ダミーのチェックリストデータ
  final List<Map<String, dynamic>> _items = [
    {'title': '玄関の鍵を閉める', 'checked': false},
    {'title': 'エアコンを消す', 'checked': false},
    {'title': '窓を閉める', 'checked': true}, // 最初からチェック済みの項目
    {'title': 'スマホを持ったか確認', 'checked': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お出かけ前チェック'),
        backgroundColor: Colors.indigo[400],
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return CheckboxListTile(
            title: Text(item['title']),
            value: item['checked'],
            onChanged: (bool? value) {
              setState(() {
                item['checked'] = value!;
              });
            },
            controlAffinity: ListTileControlAffinity.leading, // チェックボックスを左側に
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 新しい項目を追加する処理を後で書く
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
