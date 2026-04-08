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
      // マテリアル3を維持しつつ、壊れたUIを直す
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
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
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋", "玉"];

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    
    _itemController.addListener(_autoDetectItems);
  }

  @override
  void dispose() {
    _itemController.dispose();
    _countController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  // --- 最強機能：お米自動判別 ---
  void _autoDetectItems() {
    String text = _itemController.text;
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() {
          _selectedUnit = "kg";
          _selectedIcon = "🍚";
          _countController.text = "5"; // 米なら5kg提案
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
      // 計算誤差対策として非常に小さな数字で判定
      if (inventory[index]['count'] <= 0.001) {
        shoppingList.add(inventory[index]['name']);
        inventory.removeAt(index);
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    // 壊れる前のスッキリしたタブ・レイアウトを復元
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("冷蔵庫RPG - $characterMode"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.rebase_edit), text: "冒険(在庫)"),
              Tab(icon: Icon(Icons.menu_book), text: "図鑑"),
              Tab(icon: Icon(Icons.shopping_cart), text: "買出"),
            ],
          ),
        ),
        body: TabBarView(
          children: [ _buildInventoryPage(), _buildBookPage(), _buildShoppingPage() ],
        ),
      ),
    );
  }

  // --- 1. 冒険(在庫)ページ ---
  Widget _buildInventoryPage() {
    return Column(
      children: [
        // スマホでも崩れないように、Paddingを適切に取りレイアウト
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // 1段目：食材名とアイコン
              Row(
                children: [
                  DropdownButton<String>(
                    value: _selectedIcon,
                    items: ["🍎", "🥩", "🥦", "🥛", "🐟", "🍚", "🥚", "🍞"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                    onChanged: (v) => setState(() => _selectedIcon = v!),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _itemController,
                      decoration: const InputDecoration(labelText: "食材名を入力", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 2段目：数、単位、そして追加ボタン
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "数", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ★単位を自分で選べるドロップダウン（UI崩れ防止のためスリムに）
                  DropdownButton<String>(
                    value: _selectedUnit,
                    items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v!),
                  ),
                  const Spacer(), // 右端へ寄せる
                  // 追加ボタンをスッキリと
                  IconButton(icon: const Icon(Icons.add_box, color: Colors.teal, size: 40), onPressed: _addItem),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        // リスト表示（最強機能：お米の消費に対応）
        Expanded(
          child: ListView.builder(
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final item = inventory[index];
              final String unit = item['unit'] ?? "個";
              final bool isRice = unit == "kg";
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
                  title: Text(item['name']),
                  // 数を美しく表示（kgなどは小数点2桁まで）
                  subtitle: Text("${item['count'].toStringAsFixed(isRice ? 2 : 0)} $unit"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRice) ...[
                        // 最強機能：1合炊く
                        ElevatedButton(
                          onPressed: () => _updateCount(index, -0.15),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text("1合"),
                        ),
                        const SizedBox(width: 4),
                      ],
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => _updateCount(index, isRice ? -0.5 : -1)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: () => _updateCount(index, isRice ? 0.5 : 1)),
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

  // --- 2. 図鑑ページ（今回は機能復元に集中） ---
  Widget _buildBookPage() { return const Center(child: Text("図鑑モード")); }

  // --- 3. 買出ページ ---
  Widget _buildShoppingPage() { return const Center(child: Text("買出リスト")); }
}