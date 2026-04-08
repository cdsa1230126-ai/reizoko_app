// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:js' as js;

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: ReizokoApp(), debugShowCheckedModeBanner: false));
}

class ReizokoApp extends StatefulWidget {
  const ReizokoApp({super.key});
  @override
  State<ReizokoApp> createState() => _ReizokoAppState();
}

class _ReizokoAppState extends State<ReizokoApp> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  int modeIndex = 0;
  List<dynamic> inventory = [];
  List<dynamic> shoppingList = [];
  List<dynamic> recipeList = [];
  List<dynamic> monsterBook = []; 
  List<dynamic> recentlyConsumed = []; // 最近消費した食材の履歴
  
  bool autoShoppingAdd = true; // 設定：自動で買い物リストに入れるか

  Color customColor = const Color(0xFF1B5E20); 
  String selectedIcon = "🥩";
  final List<String> icons = ["🥩", "🐟", "🥦", "🍎", "🥛", "🍚", "📦"];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(text: "3");
  final TextEditingController _countController = TextEditingController(text: "1");
  String _selectedUnit = "個";
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋"];

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _loadData();
    _nameController.addListener(_autoDetectRice);
  }

  void _autoDetectRice() {
    String text = _nameController.text;
    if (text.contains("米") || text.contains("こめ") || text.contains("コメ")) {
      if (_selectedUnit != "kg") {
        setState(() { _selectedUnit = "kg"; selectedIcon = "🍚"; _countController.text = "5"; _dateController.text = "365"; });
      }
    }
  }

  // --- データの保存・読込 ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('shoppingList', jsonEncode(shoppingList));
    await prefs.setString('recipeList', jsonEncode(recipeList));
    await prefs.setString('monsterBook', jsonEncode(monsterBook));
    await prefs.setString('recentlyConsumed', jsonEncode(recentlyConsumed));
    await prefs.setBool('autoShoppingAdd', autoShoppingAdd);
    await prefs.setInt('savedColor', customColor.value);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      shoppingList = jsonDecode(prefs.getString('shoppingList') ?? "[]");
      recipeList = jsonDecode(prefs.getString('recipeList') ?? "[]");
      monsterBook = jsonDecode(prefs.getString('monsterBook') ?? "[]");
      recentlyConsumed = jsonDecode(prefs.getString('recentlyConsumed') ?? "[]");
      autoShoppingAdd = prefs.getBool('autoShoppingAdd') ?? true;
      int? colorVal = prefs.getInt('savedColor');
      if (colorVal != null) customColor = Color(colorVal);
    });
  }

  // 個数を減らす・消費する
  void _decrementItem(int index) {
    setState(() {
      double currentCount = double.tryParse(inventory[index]["count"].toString()) ?? 1.0;
      if (currentCount > 1) {
        inventory[index]["count"] = currentCount - 1;
      } else {
        var item = inventory[index];
        // 履歴に追加（重複除外）
        recentlyConsumed.removeWhere((element) => element["name"] == item["name"]);
        recentlyConsumed.insert(0, item);
        if (recentlyConsumed.length > 10) recentlyConsumed.removeLast();

        // 自動追加設定がONなら買い物リストへ
        if (autoShoppingAdd) {
          if (!shoppingList.any((s) => s["name"] == item["name"])) {
            shoppingList.add(item);
          }
        }
        _speak("${item["name"]}を使い切ったぞ！");
        inventory.removeAt(index);
      }
    });
    _saveData();
  }

  // --- UI: 冷蔵庫リスト ---
  Widget _buildInventoryView(Color textColor) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(15), width: double.infinity, color: textColor.withAlpha(20), child: Text("${charSettings[modeIndex]["name"]}\n${charSettings[modeIndex]["flavor"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
      Expanded(
        child: ListView.builder(
          itemCount: inventory.length,
          itemBuilder: (context, index) {
            final item = inventory[index];
            int days = int.tryParse(RegExp(r'\d+').stringMatch(item["limit"]) ?? "999") ?? 999;
            bool isUrgent = days <= 1;
            return Card(
              color: isUrgent ? Colors.redAccent.withAlpha((150 + (_blinkController.value * 105)).toInt()) : textColor.withAlpha(40),
              child: ListTile(
                leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 25)),
                title: Text(item["name"], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text("残り ${item["count"]} ${item["unit"] ?? '個'}", style: TextStyle(color: textColor.withAlpha(180))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(item["limit"], style: TextStyle(color: isUrgent ? Colors.white : Colors.greenAccent, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => _decrementItem(index)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // --- UI: 登録画面 ---
  Widget _buildAddView(Color textColor) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: _nameController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "食材名", labelStyle: TextStyle(color: textColor.withAlpha(150)))),
      Row(children: [
        Expanded(child: TextField(controller: _countController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "数", labelStyle: TextStyle(color: textColor.withAlpha(150))))),
        DropdownButton<String>(value: _selectedUnit, dropdownColor: Colors.black87, style: TextStyle(color: textColor), items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _selectedUnit = v!)),
        Expanded(child: TextField(controller: _dateController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "期限(日)", labelStyle: TextStyle(color: textColor.withAlpha(150))))),
      ]),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: () {
        if (_nameController.text.isNotEmpty) {
          _addItem(_nameController.text, _dateController.text, double.tryParse(_countController.text) ?? 1.0);
          _nameController.clear(); setState(() => _currentTabIndex = 0);
        }
      }, child: const Text("登録！"))
    ]));
  }

  // --- UI: 買い物リスト ＆ 履歴 ---
  void _showShoppingList() {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text("🛒 買い物リスト", style: TextStyle(color: Colors.white)),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...shoppingList.asMap().entries.map((e) => ListTile(
            leading: Text(e.value["icon"] ?? "📦"),
            title: Text(e.value["name"], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () {
              setState(() => shoppingList.removeAt(e.key)); _saveData(); setDialogState(() {});
            }),
          )),
          const Divider(color: Colors.white24),
          const Text("🍴 最近使い切ったもの", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ...recentlyConsumed.map((item) => ListTile(
            leading: Text(item["icon"] ?? "📦"),
            title: Text(item["name"], style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.add, color: Colors.yellowAccent),
            onTap: () {
              if (!shoppingList.any((s) => s["name"] == item["name"])) {
                setState(() => shoppingList.add(item)); _saveData(); setDialogState(() {});
              }
            },
          )),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("閉じる"))],
      );
    }));
  }

  void _showSettings() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("設定"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(
        title: const Text("自動買い物登録"),
        subtitle: const Text("使い切ると自動でリストへ"),
        value: autoShoppingAdd,
        onChanged: (v) { setState(() => autoShoppingAdd = v); _saveData(); Navigator.pop(context); },
      ),
      const Divider(),
      const Text("モード切替"),
      ...List.generate(3, (i) => RadioListTile(value: i, groupValue: modeIndex, title: Text(charSettings[i]["name"]), onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(context); })),
    ])));
  }

  void _addItem(String name, String date, double count) {
    setState(() {
      inventory.add({"name": name, "icon": selectedIcon, "limit": "あと${date}日", "count": count, "unit": _selectedUnit});
      if (!monsterBook.any((m) => m["name"] == name)) monsterBook.add({"name": name, "icon": selectedIcon});
    });
    _saveData();
  }

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "flavor": "「魔物を倒して食卓を豊かにするのじゃ！」"},
    {"name": "🧑‍⚕️ ドクター", "flavor": "「栄養を管理しましょう。」"},
    {"name": "🕶️ トレーダー", "flavor": "「資産の回転率を上げろ。」"}
  ];

  void _speak(String text) {
    js.context.callMethod('eval', ["""window.speechSynthesis.cancel(); const uttr = new SpeechSynthesisUtterance('$text'); uttr.lang = 'ja-JP'; window.speechSynthesis.speak(uttr);"""]);
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = customColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(title: Text(charSettings[modeIndex]["name"], style: TextStyle(color: textColor)), backgroundColor: Colors.transparent, elevation: 0, actions: [IconButton(onPressed: _showShoppingList, icon: const Icon(Icons.shopping_cart)), IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings))]),
      body: IndexedStack(index: _currentTabIndex, children: [_buildInventoryView(textColor), _buildAddView(textColor), const Center(child: Text("レシピ/図鑑"))]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _currentTabIndex, onTap: (i) => setState(() => _currentTabIndex = i), backgroundColor: Colors.black.withAlpha(200), selectedItemColor: Colors.yellowAccent, unselectedItemColor: Colors.white54, items: const [BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "冷蔵庫"), BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "登録"), BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ")]),
    );
  }
}