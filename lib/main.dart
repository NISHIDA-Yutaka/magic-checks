import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Webかどうかを判定するために使用
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'firebase_options.dart';
import 'dart:math';

// --- アプリ全体のナビゲーション設定 ---
final _router = GoRouter(
  initialLocation: '/lists',
  routes: [
    GoRoute(
      path: '/lists',
      builder: (context, state) => const ChecklistListScreen(),
    ),
    GoRoute(
      path: '/lists/:listId',
      builder: (context, state) {
        final listId = state.pathParameters['listId']!;
        return ChecklistDetailScreen(checklistId: listId);
      },
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const QRScannerScreen(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MagicChecksApp());
}

class MagicChecksApp extends StatelessWidget {
  const MagicChecksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'MagicChecks',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade400,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

//--- 画面1: チェックリスト一覧画面 ---
class ChecklistListScreen extends StatefulWidget {
  const ChecklistListScreen({super.key});

  @override
  State<ChecklistListScreen> createState() => _ChecklistListScreenState();
}

class _ChecklistListScreenState extends State<ChecklistListScreen> {
  final TextEditingController _titleController = TextEditingController();
  final CollectionReference _checklistsCollection =
      FirebaseFirestore.instance.collection('checklists');

  Future<void> _showAddListDialog() async {
    _titleController.clear();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新しいチェックリストを作成'),
          content: TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: "リストのタイトル (例: 旅行の準備)"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('作成'),
              onPressed: () {
                if (_titleController.text.isNotEmpty) {
                  final randomColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];
                  final randomIcon = _getRandomIcon();
                  _checklistsCollection.add({
                    'title': _titleController.text,
                    'createdAt': Timestamp.now(),
                    'color': randomColor.value,
                    'icon': randomIcon.codePoint,
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getRandomIcon() {
    final icons = [
      FontAwesomeIcons.suitcase, FontAwesomeIcons.car, FontAwesomeIcons.house,
      FontAwesomeIcons.cartShopping, FontAwesomeIcons.personWalking, FontAwesomeIcons.briefcase,
      FontAwesomeIcons.book, FontAwesomeIcons.pills, FontAwesomeIcons.paw,
    ];
    return icons[Random().nextInt(icons.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MagicChecks', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.qrcode),
            tooltip: 'QRコードをスキャン',
            onPressed: () => context.go('/scanner'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _checklistsCollection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('エラーが発生しました'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.solidNoteSticky, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('チェックリストがありません', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('右下の「＋」ボタンから最初のリストを作成しましょう', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final checklistColor = Color(data['color'] ?? Colors.grey.value);
              final checklistIcon = IconData(data['icon'] ?? FontAwesomeIcons.question.codePoint, fontFamily: 'FontAwesomeSolid');

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: checklistColor,
                    child: FaIcon(checklistIcon, color: Colors.white, size: 20),
                  ),
                  title: Text(data['title'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () => context.go('/lists/${doc.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddListDialog,
        tooltip: '新しいリストを作成',
        child: const Icon(Icons.add),
      ),
    );
  }
}

//--- 画面2: チェックリスト詳細画面 ---
class ChecklistDetailScreen extends StatelessWidget {
  final String checklistId;

  const ChecklistDetailScreen({super.key, required this.checklistId});

  @override
  Widget build(BuildContext context) {
    final DocumentReference checklistDocRef =
        FirebaseFirestore.instance.collection('checklists').doc(checklistId);

    return StreamBuilder<DocumentSnapshot>(
      stream: checklistDocRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('リストが見つかりません')),
          );
        }
        final checklistData = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          appBar: AppBar(
            title: Text(checklistData['title']),
            actions: [
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.shareNodes),
                tooltip: 'QRコードで共有',
                onPressed: () => _showQRCodeDialog(context, checklistId),
              ),
            ],
          ),
          body: ChecklistItems(checklistDocRef: checklistDocRef),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddItemDialog(context, checklistDocRef.collection('items')),
            tooltip: '項目を追加',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

void _showQRCodeDialog(BuildContext context, String listId) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('このリストをQRコードで開く', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: listId,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 20),
            const Text('IDをコピーして手入力もできます', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            SelectableText(
              listId,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

// 詳細画面の項目リスト部分
class ChecklistItems extends StatefulWidget {
  final DocumentReference checklistDocRef;
  const ChecklistItems({super.key, required this.checklistDocRef});

  @override
  State<ChecklistItems> createState() => _ChecklistItemsState();
}

class _ChecklistItemsState extends State<ChecklistItems> {
  late final CollectionReference _itemsCollection;

  @override
  void initState() {
    super.initState();
    _itemsCollection = widget.checklistDocRef.collection('items');
  }

  Future<void> _updateItem(DocumentSnapshot doc, bool checked) async {
    await doc.reference.update({'checked': checked});
  }

  Future<void> _deleteItem(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _itemsCollection.orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('エラーが発生しました'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final item = doc.data() as Map<String, dynamic>;
            return Dismissible(
              key: Key(doc.id),
              onDismissed: (direction) {
                _deleteItem(doc);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item['title']} を削除しました')),
                );
              },
              background: Container(
                color: Colors.red.shade300,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  item['title'],
                  style: TextStyle(
                    decoration: item['checked'] ? TextDecoration.lineThrough : TextDecoration.none,
                    color: item['checked'] ? Colors.grey : null,
                  ),
                ),
                value: item['checked'],
                onChanged: (bool? value) => _updateItem(doc, value!),
              ),
            );
          },
        );
      },
    );
  }
}

// 項目追加ダイアログ
void _showAddItemDialog(BuildContext context, CollectionReference itemsCollection) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('新しい項目を追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "チェックする内容"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('追加'),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                itemsCollection.add({
                  'title': controller.text,
                  'checked': false,
                  'createdAt': Timestamp.now(),
                });
                Navigator.pop(context);
              }
            },
          ),
        ],
      );
    },
  );
}

//--- 画面3: QRコードスキャナー画面 ---
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _debugInputController = TextEditingController();
  bool _isNavigating = false;

  void _handleScannedCode(String code) {
    if (_isNavigating) return;
    if (code.isNotEmpty) {
      setState(() { _isNavigating = true; });
      context.go('/lists/$code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRコードをスキャン'),
        actions: [
          // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
          // ★★★ 修正点: 状態監視をやめ、シンプルなトグルボタンに変更 ★★★
          // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.flash_on), // アイコンを固定
              tooltip: '懐中電灯を切り替え',
              onPressed: () => _scannerController.toggleTorch(),
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final String? code = capture.barcodes.first.rawValue;
              if (code != null) {
                _handleScannedCode(code);
              }
            },
          ),
          if (kIsWeb)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('【デバッグ用】リストIDをペースト', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _debugInputController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'ここにIDを貼り付け',
                              hintStyle: TextStyle(color: Colors.white70),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _handleScannedCode(_debugInputController.text),
                          child: const Text('スキャン実行'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _debugInputController.dispose();
    super.dispose();
  }
}
