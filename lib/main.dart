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
    debugPrint("カメラが見つかりません: $e");
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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
  final TextEditingController _countController = TextEditingController(text: "1");
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3));
  String _selectedIcon = "🍎";
  String _selectedUnit = "個";
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "袋"];

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
    _itemController.removeListener(_autoDetectItems);
    _itemController.dispose();
    _countController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _autoDetectItems() {
    String text = _itemController.text;
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() {
          _selectedUnit = "kg";
          _selectedIcon = "🍚";
          _countController.text = "5";
          _selectedDate = DateTime.now().add(const Duration(days: 365));
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
    String name = _itemController.text;

    setState(() {
      inventory.add({
        "name": name,
        "icon": _selectedIcon,
        "count": double.tryParse(_countController.text) ?? 1.0,
        "unit": _selectedUnit,
        "expiry": _selectedDate.toIso8601String(),
      });

      if (!monsterBook.any((m) => m['name'] == name)) {
        monsterBook.add({"name": name, "icon": _selectedIcon});
        _speak(characterMode == "長老" ? "新種の魔物 $name の発見じゃ！" : "登録完了。");
      }
      _itemController.clear();
      _countController.text = "1";
    });
    _saveData();
  }

  void _consumeItem(int index, {double amount = 1.0}) {
    setState(() {
      inventory[index]['count'] -= amount;
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
          actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)],
        ),
        body: TabBarView(
          children: [ _buildMainPage(), _buildMonsterBook(), _buildShoppingList() ],
        ),
      ),
    );
  }

  Widget _buildMainPage() {
    return Column(
      children: [
        // --- ここが復元した1行入力エリア ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _selectedIcon,
                underline: const SizedBox(),
                items: ["🍎", "🥩", "🥦", "🥛", "🐟", "🍚", "🥚"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                onChanged: (v) => setState(() => _selectedIcon = v!),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 4,
                child: TextField(controller: _itemController, decoration: const InputDecoration(hintText: "食材名", isDense: true)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(controller: _countController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "1", isDense: true)),
              ),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: _selectedUnit,
                underline: const SizedBox(),
                items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _selectedUnit = v!),
              ),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal, size: 40), onPressed: _addItem),
            ],
          ),
        ),
        // 期限選択ボタン
        TextButton.icon(
          icon: const Icon(Icons.event, size: 18),
          onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (date != null) setState(() => _selectedDate = date);
          },
          label: Text("期限: ${_selectedDate.month}/${_selectedDate.day}"),
        ),
        const Divider(),
        Expanded(child: _buildInventoryList()),
      ],
    );
  }

  Widget _buildInventoryList() {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final String unit = item['unit'] ?? "個";
        final bool isKg = unit == "kg";
        final expiry = DateTime.parse(item['expiry']);
        final isUrgent = expiry.difference(DateTime.now()).inDays <= 1;
        return AnimatedBuilder(
          animation: _blinkController,
          builder: (context, child) {
            return Card(
              color: isUrgent ? Colors.red.withAlpha((25 + 75 * _blinkController.value).toInt()) : Colors.white,
              child: ListTile(
                leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
                title: Text(item['name']),
                subtitle: Text("期限: ${expiry.month}/${expiry.day} | 残量: ${item['count'].toStringAsFixed(isKg ? 2 : 0)} $unit"),
                trailing: isKg 
                  ? ElevatedButton(onPressed: () => _consumeItem(index, amount: 0.15), child: const Text("1合"))
                  : IconButton(icon: const Icon(Icons.restaurant, color: Colors.orange), onPressed: () => _consumeItem(index)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonsterBook() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemCount: monsterBook.length,
      itemBuilder: (context, index) {
        final monster = monsterBook[index];
        bool isAlive = inventory.any((item) => item['name'] == monster['name']);
        return Card(
          color: isAlive ? Colors.green.shade50 : Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(monster['icon'], style: const TextStyle(fontSize: 30)),
              Text(monster['name'], style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShoppingList() {
    return ListView.builder(
      itemCount: shoppingList.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.shopping_bag, color: Colors.blue),
          title: Text(shoppingList[index]),
          trailing: IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () {
            setState(() => shoppingList.removeAt(index));
            _saveData();
          }),
        );
      },
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("設定"),
        content: DropdownButton<String>(
          value: characterMode,
          items: ["長老", "ドクター", "トレーダー"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) {
            setState(() => characterMode = v!);
            _saveData();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}