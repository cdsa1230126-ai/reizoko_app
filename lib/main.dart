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
  String _selectedIcon = "🍎";
  String _selectedUnit = "個";
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋", "玉"];

  @override
  void initState() {
    super.initState();
    _loadData();
    _itemController.addListener(_autoDetectItems);
  }

  @override
  void dispose() {
    _itemController.removeListener(_autoDetectItems);
    _itemController.dispose();
    _countController.dispose();
    super.dispose();
  }

  // 自動判別アシスト
  void _autoDetectItems() {
    String text = _itemController.text;
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() { _selectedUnit = "kg"; _selectedIcon = "🍚"; _countController.text = "5"; });
      }
    } else if (text.contains("牛乳") || text.contains("ミルク") || text.contains("酒")) {
      if (_selectedUnit != "ml") {
        setState(() { _selectedUnit = "ml"; _selectedIcon = "🥛"; _countController.text = "1000"; });
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = List<Map<String, dynamic>>.from(json.decode(prefs.getString('inventory') ?? '[]'));
      shoppingList = prefs.getStringList('shoppingList') ?? [];
      monsterBook = List<Map<String, dynamic>>.from(json.decode(prefs.getString('monsterBook') ?? '[]'));
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', json.encode(inventory));
    await prefs.setStringList('shoppingList', shoppingList);
    await prefs.setString('monsterBook', json.encode(monsterBook));
  }

  void _addItem() {
    if (_itemController.text.isEmpty) return;
    setState(() {
      inventory.add({
        "name": _itemController.text,
        "icon": _selectedIcon,
        "count": double.tryParse(_countController.text) ?? 1.0,
        "unit": _selectedUnit,
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
            tabs: [Tab(text: "冒険(在庫)"), Tab(text: "図鑑"), Tab(text: "買出リスト")],
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
          child: Column(
            children: [
              // 1段目: アイコン選択と名前入力
              Row(
                children: [
                  DropdownButton<String>(
                    value: _selectedIcon,
                    items: ["🍎", "🥩", "🥦", "🥛", "🐟", "🍚", "🥚"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                    onChanged: (v) => setState(() => _selectedIcon = v!),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _itemController, decoration: const InputDecoration(labelText: "食材名を入力", border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 10),
              // 2段目: 数量と単位選択
              Row(
                children: [
                  SizedBox(width: 80, child: TextField(controller: _countController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "数", border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedUnit,
                    items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v!),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text("保管"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100),
                  ),
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
              final bool isKg = item['unit'] == "kg";
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
                  title: Text(item['name']),
                  subtitle: Text("${item['count'].toStringAsFixed(isKg ? 2 : 0)} ${item['unit']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isKg) ...[
                        ElevatedButton(onPressed: () => _updateCount(index, -0.15), child: const Text("1合")),
                        const SizedBox(width: 4),
                        ElevatedButton(onPressed: () => _updateCount(index, -0.30), child: const Text("2合")),
                      ] else ...[
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => _updateCount(index, -1)),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: () => _updateCount(index, 1)),
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

  Widget _buildBookPage() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemCount: monsterBook.length,
      itemBuilder: (context, index) {
        final monster = monsterBook[index];
        bool inStock = inventory.any((i) => i['name'] == monster['name']);
        return Card(
          color: inStock ? Colors.orange.shade50 : Colors.grey.shade200,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(monster['icon'], style: const TextStyle(fontSize: 30)), Text(monster['name'])]),
        );
      },
    );
  }

  Widget _buildShoppingPage() {
    return ListView.builder(
      itemCount: shoppingList.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.shopping_cart, color: Colors.orange),
          title: Text(shoppingList[index]),
          trailing: const Text("要討伐(未購入)", style: TextStyle(color: Colors.red, fontSize: 12)),
          onTap: () => setState(() => shoppingList.removeAt(index)),
        );
      },
    );
  }
}