import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("カメラが見つかりません: $e");
  }
  runApp(ReizokoApp(cameras: cameras));
}

class ReizokoApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const ReizokoApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '冷蔵庫RPG',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange.shade800),
        useMaterial3: true,
      ),
      home: ReizokoHomePage(cameras: cameras),
    );
  }
}

class ReizokoHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ReizokoHomePage({super.key, required this.cameras});

  @override
  State<ReizokoHomePage> createState() => _ReizokoHomePageState();
}

class _ReizokoHomePageState extends State<ReizokoHomePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> inventory = [];
  List<String> shoppingList = [];
  List<Map<String, dynamic>> monsterBook = [];
  String characterMode = "長老";
  
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: "1");
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  String _selectedIcon = "🍎";
  String _selectedUnit = "個";

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // 【重要】入力欄の文字が変わるたびにチェックする設定
    _itemController.addListener(_onItemNameChanged);
  }

  @override
  void dispose() {
    _itemController.removeListener(_onItemNameChanged);
    _itemController.dispose();
    _countController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  // 入力された名前を見て「kg」にするかどうか判断する
  void _onItemNameChanged() {
    String text = _itemController.text;
    // 「米」が含まれているかチェック
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() {
          _selectedUnit = "kg";      // 単位をkgに
          _selectedIcon = "🍚";      // アイコンをお米に
          _countController.text = "5"; // とりあえず5kgにセット
        });
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = List<Map<String, dynamic>>.from(json.decode(prefs.getString('inventory') ?? '[]'));
      shoppingList = prefs.getStringList('shoppingList') ?? [];
      monsterBook = List<Map<String, dynamic>>.from(json.decode(prefs.getString('monsterBook') ?? '[]'));
      characterMode = prefs.getString('characterMode') ?? "長老";
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', json.encode(inventory));
    await prefs.setStringList('shoppingList', shoppingList);
    await prefs.setString('monsterBook', json.encode(monsterBook));
    await prefs.setString('characterMode', characterMode);
  }

  void _speak(String text) {
    final utterance = html.SpeechSynthesisUtterance(text)..lang = 'ja-JP';
    html.window.speechSynthesis?.speak(utterance);
  }

  void _addItem() {
    if (_itemController.text.isEmpty) return;
    setState(() {
      inventory.add({
        "name": _itemController.text,
        "icon": _selectedIcon,
        "count": double.tryParse(_countController.text) ?? 1.0,
        "unit": _selectedUnit,
        "expiry": _selectedDate.toIso8601String(),
      });
      if (!monsterBook.any((m) => m['name'] == _itemController.text)) {
        monsterBook.add({"name": _itemController.text, "icon": _selectedIcon});
      }
      _itemController.clear();
      _countController.text = "1";
      _selectedUnit = "個"; 
    });
    _saveData();
    _speak("保管完了じゃ。");
  }

  void _consumeRice(int index, double goCount) {
    setState(() {
      double weight = goCount * 0.15; // 1合=0.15kg
      inventory[index]['count'] -= weight;
      if (inventory[index]['count'] <= 0) {
        shoppingList.add(inventory[index]['name']);
        inventory.removeAt(index);
        _speak("米が尽きたぞ！");
      }
    });
    _saveData();
  }

  void _updateCount(int index, double delta) {
    setState(() {
      inventory[index]['count'] += delta;
      if (inventory[index]['count'] <= 0) {
        shoppingList.add(inventory[index]['name']);
        inventory.removeAt(index);
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("冷蔵庫RPG - $characterMode"),
          bottom: const TabBar(
            tabs: [Tab(text: "在庫"), Tab(text: "図鑑"), Tab(text: "買出")],
          ),
        ),
        body: TabBarView(
          children: [ _buildInventoryPage(), _buildBookPage(), _buildShoppingPage() ],
        ),
      ),
    );
  }

  Widget _buildInventoryPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(_selectedIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _itemController,
                  decoration: const InputDecoration(labelText: "食材名（米と入れるとkgになります）"),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: TextField(controller: _countController, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              // 現在の単位を表示
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                child: Text(_selectedUnit),
              ),
              IconButton(icon: const Icon(Icons.add_box, color: Colors.green, size: 35), onPressed: _addItem),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final item = inventory[index];
              final bool isRice = item['unit'] == "kg";
              return Card(
                child: ListTile(
                  leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
                  title: Text(item['name']),
                  subtitle: Text("${item['count'].toStringAsFixed(2)} ${item['unit']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRice) ...[
                        ElevatedButton(onPressed: () => _consumeRice(index, 1), child: const Text("1合")),
                        const SizedBox(width: 4),
                        ElevatedButton(onPressed: () => _consumeRice(index, 2), child: const Text("2合")),
                      ] else ...[
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _updateCount(index, -1)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _updateCount(index, 1)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookPage() { return const Center(child: Text("図鑑モード")); }
  Widget _buildShoppingPage() { return const Center(child: Text("買出リスト")); }
}