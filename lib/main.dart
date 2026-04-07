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

class ReizokoApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ReizokoApp({super.key, required this.cameras});

  @override
  State<ReizokoApp> createState() => _ReizokoAppState();
}

class _ReizokoAppState extends State<ReizokoApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '冷蔵庫RPG',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown), // お米・大地の色
        useMaterial3: true,
      ),
      home: ReizokoHomePage(cameras: widget.cameras),
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
  final TextEditingController _countController = TextEditingController(text: "5"); // 米5kgなどを想定
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _selectedIcon = "🍚";
  String _selectedUnit = "kg"; 

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
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
    String name = _itemController.text;
    double count = double.tryParse(_countController.text) ?? 1.0;

    setState(() {
      inventory.add({
        "name": name,
        "icon": _selectedIcon,
        "count": count,
        "unit": _selectedUnit,
        "expiry": _selectedDate.toIso8601String(),
      });
      if (!monsterBook.any((m) => m['name'] == name)) {
        monsterBook.add({"name": name, "icon": _selectedIcon, "unit": _selectedUnit});
      }
      _itemController.clear();
    });
    _saveData();
    _speak("$name を保管庫に入れたぞ。");
  }

  // --- 重さ・合数の換算ロジック ---
  void _consumeRice(int index, double goCount) {
    setState(() {
      // 1合 = 0.15kg として計算
      double consumeWeight = goCount * 0.15;
      inventory[index]['count'] = (inventory[index]['count'] - consumeWeight);
      
      if (inventory[index]['count'] <= 0.01) { // ほぼ0になったら削除
        String name = inventory[index]['name'];
        if (!shoppingList.contains(name)) shoppingList.add(name);
        inventory.removeAt(index);
        _speak(characterMode == "長老" ? "米びつが空じゃ！買い出しに行くのじゃ。" : "お米がなくなりました。");
      } else {
        _speak("$goCount 合 炊いたな。残り ${(inventory[index]['count'] as double).toStringAsFixed(2)} キロじゃ。");
      }
    });
    _saveData();
  }

  void _updateCount(int index, double delta) {
    setState(() {
      inventory[index]['count'] = (inventory[index]['count'] + delta);
      if (inventory[index]['count'] <= 0) {
        String name = inventory[index]['name'];
        if (!shoppingList.contains(name)) shoppingList.add(name);
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
            tabs: [Tab(icon: Icon(Icons.rebase_edit), text: "在庫"), Tab(icon: Icon(Icons.menu_book), text: "図鑑"), Tab(icon: Icon(Icons.shopping_cart), text: "買出")],
          ),
        ),
        body: TabBarView(children: [ _buildMainPage(), _buildMonsterBook(), _buildShoppingList() ]),
      ),
    );
  }

  Widget _buildMainPage() {
    return Column(children: [_buildInputArea(), const Divider(), Expanded(child: _buildInventoryList())]);
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              DropdownButton<String>(
                value: _selectedIcon,
                items: ["🍚", "🥩", "🥦", "🥛", "🐟", "🍎"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                onChanged: (v) => setState(() => _selectedIcon = v!),
              ),
              Expanded(child: TextField(controller: _itemController, decoration: const InputDecoration(labelText: "食材名（例: お米）"))),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: TextField(controller: _countController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "量"))),
              DropdownButton<String>(
                value: _selectedUnit,
                items: ["kg", "g", "個", "本"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _selectedUnit = v!),
              ),
              IconButton(icon: const Icon(Icons.add_box, color: Colors.green, size: 35), onPressed: _addItem),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final String unit = item['unit'] ?? "個";
        final double count = item['count'];
        final bool isRice = unit == "kg"; // kg登録のものを米として扱う

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListTile(
            leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
            title: Text(item['name']),
            subtitle: Text("在庫: ${count.toStringAsFixed(2)} $unit"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRice) ...[
                  // お米専用：合で減らすボタン
                  ElevatedButton(
                    onPressed: () => _consumeRice(index, 1),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), backgroundColor: Colors.orange.shade50),
                    child: const Text("1合炊く", style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () => _consumeRice(index, 2),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), backgroundColor: Colors.orange.shade100),
                    child: const Text("2合", style: TextStyle(fontSize: 11)),
                  ),
                ] else ...[
                  // 通常食材：1個ずつ減らす
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => _updateCount(index, -1)),
                ],
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: () => _updateCount(index, isRice ? 0.5 : 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 以下、図鑑と買い物リストは前回同様 ---
  Widget _buildMonsterBook() { /* 前回と同じ GridView.builder ... */ return const Center(child: Text("図鑑は冒険の記録じゃ")); }
  Widget _buildShoppingList() { /* 前回と同じ ListView.builder ... */ return const Center(child: Text("買い出しメモじゃ")); }
}