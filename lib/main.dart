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
    print("カメラ準備完了（Web）");
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
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
  
  // 最強の単位ラインナップ
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋", "玉", "切"];
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
    
    // 食材名の入力監視
    _itemController.addListener(_autoDetectItems);
  }

  @override
  void dispose() {
    _itemController.dispose();
    _countController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  // 入力された文字から単位とアイコンを自動予測
  void _autoDetectItems() {
    String text = _itemController.text;
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() { _selectedUnit = "kg"; _selectedIcon = "🍚"; _countController.text = "5"; });
      }
    } else if (text.contains("牛乳") || text.contains("ミルク") || text.contains("酒") || text.contains("水")) {
      if (_selectedUnit != "ml" && _selectedUnit != "L") {
        setState(() { _selectedUnit = "ml"; _selectedIcon = "🥛"; _countController.text = "1000"; });
      }
    } else if (text.contains("肉") || text.contains("にく")) {
      setState(() { _selectedIcon = "🥩"; });
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
  }

  void _updateCount(int index, double delta) {
    setState(() {
      inventory[index]['count'] += delta;
      if (inventory[index]['count'] <= 0.001) {
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
          bottom: const TabBar(tabs: [Tab(text: "冒険(在庫)"), Tab(text: "図鑑"), Tab(text: "買出リスト")]),
        ),
        body: TabBarView(children: [ _buildInventoryPage(), _buildBookPage(), _buildShoppingPage() ]),
      ),
    );
  }

  Widget _buildInventoryPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    value: _selectedIcon,
                    items: ["🍎", "🥩", "🥦", "🥛", "🐟", "🍚", "🥚", "🍞"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                    onChanged: (v) => setState(() => _selectedIcon = v!),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _itemController, decoration: const InputDecoration(labelText: "食材名"))),
                  const SizedBox(width: 8),
                  SizedBox(width: 50, child: TextField(controller: _countController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "数"))),
                  const SizedBox(width: 8),
                  // ★単位を自由に選べるドロップダウン
                  DropdownButton<String>(
                    value: _selectedUnit,
                    items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v!),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal, size: 40), onPressed: _addItem),
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
              final String unit = item['unit'] ?? "個";
              final bool isKg = unit == "kg";
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
                  title: Text(item['name']),
                  subtitle: Text("${item['count'].toStringAsFixed(2)} $unit"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isKg) ...[
                        ElevatedButton(
                          onPressed: () => _updateCount(index, -0.15),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text("1合炊く"),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => _updateCount(index, isKg ? -0.5 : -1)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: () => _updateCount(index, isKg ? 0.5 : 1)),
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

  Widget _buildBookPage() { return const Center(child: Text("図鑑モード：発見した食材が記録されます")); }
  Widget _buildShoppingPage() { return const Center(child: Text("買出リスト：使い切った食材がここに並びます")); }
}