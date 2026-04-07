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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange.shade900),
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

    // 食材名の入力を監視して、自動で単位を変える設定
    _itemController.addListener(_autoDetectRice);
  }

  @override
  void dispose() {
    _itemController.removeListener(_autoDetectRice);
    _itemController.dispose();
    _countController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  // 「米」という文字が入ったら自動で kg と 5 に設定する
  void _autoDetectRice() {
    String text = _itemController.text;
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() {
          _selectedUnit = "kg";
          _selectedIcon = "🍚";
          _countController.text = "5"; // お米ならとりあえず5kgを提案
        });
      }
    }
  }

  // --- データの保存・読込 ---
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

  // --- 食材追加 ---
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
      _selectedUnit = "個"; // 追加後はリセット
    });
    _saveData();
    _speak("新しい魔物を保管したぞ。");
  }

  // --- 消費ロジック ---
  void _consumeRice(int index, double goCount) {
    setState(() {
      double weight = goCount * 0.15; // 1合 = 0.15kg
      inventory[index]['count'] -= weight;
      if (inventory[index]['count'] <= 0) {
        if (!shoppingList.contains(inventory[index]['name'])) shoppingList.add(inventory[index]['name']);
        inventory.removeAt(index);
        _speak("米が尽きた！買出リストに書いたぞ。");
      }
    });
    _saveData();
  }

  void _updateCount(int index, double delta) {
    setState(() {
      inventory[index]['count'] += delta;
      if (inventory[index]['count'] <= 0) {
        if (!shoppingList.contains(inventory[index]['name'])) shoppingList.add(inventory[index]['name']);
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
            tabs: [Tab(icon: Icon(Icons.inventory), text: "在庫"), Tab(icon: Icon(Icons.menu_book), text: "図鑑"), Tab(icon: Icon(Icons.shopping_cart), text: "買出")],
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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    value: _selectedIcon,
                    items: ["🍎", "🥩", "🥦", "🥛", "🐟", "🍚"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                    onChanged: (v) => setState(() => _selectedIcon = v!),
                  ),
                  Expanded(child: TextField(controller: _itemController, decoration: const InputDecoration(labelText: "食材名を入力（『米』で自動切替）"))),
                  const SizedBox(width: 8),
                  SizedBox(width: 45, child: TextField(controller: _countController, keyboardType: TextInputType.number)),
                  DropdownButton<String>(
                    value: _selectedUnit,
                    items: ["個", "kg", "g", "本"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v!),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 35), onPressed: _addItem),
                ],
              ),
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

  Widget _buildBookPage() { return GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3), itemCount: monsterBook.length, itemBuilder: (context, index) {
    final monster = monsterBook[index];
    bool inStock = inventory.any((i) => i['name'] == monster['name']);
    return Card(color: inStock ? Colors.orange.shade50 : Colors.grey.shade200, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(monster['icon'], style: const TextStyle(fontSize: 30)), Text(monster['name'])]));
  }); }

  Widget _buildShoppingPage() { return ListView.builder(itemCount: shoppingList.length, itemBuilder: (context, index) {
    return ListTile(leading: const Icon(Icons.shopping_cart), title: Text(shoppingList[index]), onTap: () => setState(() => shoppingList.removeAt(index)));
  }); }
}