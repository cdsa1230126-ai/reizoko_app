// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;

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
  List<dynamic> recentlyConsumed = [];
  bool autoShoppingAdd = true;
  Color customColor = const Color(0xFF1B5E20);

  // --- 食材マスタ (2段階プルダウン用) ---
  final Map<String, List<Map<String, dynamic>>> _foodMaster = {
    "肉類": [
      {"name": "牛肉", "icon": "🥩", "limit": 3},
      {"name": "豚肉", "icon": "🥩", "limit": 3},
      {"name": "鶏肉", "icon": "🍗", "limit": 2},
      {"name": "ひき肉", "icon": "🥩", "limit": 2},
      {"name": "ハム・ソーセージ", "icon": "🥓", "limit": 7},
    ],
    "魚介類": [
      {"name": "鮭", "icon": "🐟", "limit": 2},
      {"name": "鯖", "icon": "🐟", "limit": 2},
      {"name": "刺身", "icon": "🍣", "limit": 1},
      {"name": "エビ・カニ", "icon": "🦀", "limit": 2},
      {"name": "貝類", "icon": "🐚", "limit": 2},
    ],
    "野菜・果物": [
      {"name": "キャベツ", "icon": "🥬", "limit": 7},
      {"name": "レタス", "icon": "🥗", "limit": 4},
      {"name": "トマト", "icon": "🍅", "limit": 5},
      {"name": "玉ねぎ", "icon": "🧅", "limit": 21},
      {"name": "人参", "icon": "🥕", "limit": 14},
      {"name": "じゃがいも", "icon": "🥔", "limit": 30},
      {"name": "りんご", "icon": "🍎", "limit": 14},
      {"name": "バナナ", "icon": "🍌", "limit": 5},
    ],
    "乳製品・卵": [
      {"name": "牛乳", "icon": "🥛", "limit": 5},
      {"name": "卵", "icon": "🥚", "limit": 14},
      {"name": "ヨーグルト", "icon": "🍦", "limit": 7},
      {"name": "チーズ", "icon": "🧀", "limit": 30},
      {"name": "バター", "icon": "🧈", "limit": 60},
    ],
    "主食・その他": [
      {"name": "米", "icon": "🍚", "limit": 365},
      {"name": "パン", "icon": "🍞", "limit": 3},
      {"name": "豆腐", "icon": "⬜", "limit": 3},
      {"name": "納豆", "icon": "🍱", "limit": 7},
      {"name": "マヨネーズ", "icon": "🧴", "limit": 180},
    ],
  };

  String _selectedCategory = "肉類";
  String _selectedFoodName = "牛肉";
  String selectedIcon = "🥩";

  // --- カラーパレット ---
  final List<Map<String, dynamic>> colorPalette = [
    {"name": "IndianRed", "color": Color(0xFFCD5C5C)},
    {"name": "Salmon", "color": Color(0xFFFA8072)},
    {"name": "Crimson", "color": Color(0xFFDC143C)},
    {"name": "DeepPink", "color": Color(0xFFFF1493)},
    {"name": "Coral", "color": Color(0xFFFF7F50)},
    {"name": "Orange", "color": Color(0xFFFFA500)},
    {"name": "Gold", "color": Color(0xFFFFD700)},
    {"name": "Yellow", "color": Color(0xFFFFFF00)},
    {"name": "Violet", "color": Color(0xFFEE82EE)},
    {"name": "Purple", "color": Color(0xFF800080)},
    {"name": "Green", "color": Color(0xFF008000)},
    {"name": "ForestGreen", "color": Color(0xFF228B22)},
    {"name": "Teal", "color": Color(0xFF008080)},
    {"name": "SkyBlue", "color": Color(0xFF87CEEB)},
    {"name": "Blue", "color": Color(0xFF0000FF)},
    {"name": "Navy", "color": Color(0xFF233B6C)},
    {"name": "Black", "color": Color(0xFF000000)},
    {"name": "真紅", "color": Color(0xFFB13546)},
    {"name": "山吹色", "color": Color(0xFFF8B400)},
  ];

  final TextEditingController _dateController = TextEditingController(text: "3");
  final TextEditingController _countController = TextEditingController(text: "1");
  String _selectedUnit = "個";
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋", "匹"];

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _dateController.dispose();
    _countController.dispose();
    super.dispose();
  }

  // --- ロジック ---
  void _onCategoryChanged(String? newCat) {
    if (newCat == null) return;
    setState(() {
      _selectedCategory = newCat;
      _selectedFoodName = _foodMaster[newCat]![0]["name"];
      _updateAutoFields(_selectedFoodName);
    });
  }

  void _onFoodChanged(String? newName) {
    if (newName == null) return;
    setState(() {
      _selectedFoodName = newName;
      _updateAutoFields(newName);
    });
  }

  void _updateAutoFields(String foodName) {
    final foodData = _foodMaster[_selectedCategory]!.firstWhere((e) => e["name"] == foodName);
    selectedIcon = foodData["icon"];
    _dateController.text = foodData["limit"].toString();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('shoppingList', jsonEncode(shoppingList));
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
      recentlyConsumed = jsonDecode(prefs.getString('recentlyConsumed') ?? "[]");
      autoShoppingAdd = prefs.getBool('autoShoppingAdd') ?? true;
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  void _consumeItem(int index) {
    var item = inventory[index];
    recentlyConsumed.removeWhere((e) => e["name"] == item["name"]);
    recentlyConsumed.insert(0, item);
    if (autoShoppingAdd && !shoppingList.any((s) => s["name"] == item["name"])) {
      shoppingList.add(item);
    }
    _speak("${item["name"]}を使い切ったぞ！");
    inventory.removeAt(index);
    _saveData();
  }

  void _updateItemCount(int index, double newCount) {
    setState(() {
      if (newCount <= 0) {
        _consumeItem(index);
      } else {
        inventory[index]["count"] = newCount;
        _saveData();
      }
    });
  }

  // --- UI: 冷蔵庫リスト ---
  Widget _buildInventoryView(Color textColor) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.campaign, color: Colors.yellowAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(inventory.isEmpty ? "庫内は空っぽじゃ。獲物を登録せよ！" : "現在の在庫：${inventory.length} 種類", style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: inventory.length,
          itemBuilder: (context, index) {
            final item = inventory[index];
            final limitDays = int.tryParse(item["limit"].replaceAll(RegExp(r'[^0-9]'), '')) ?? 99;
            double currentVal = double.tryParse(item["count"].toString()) ?? 1.0;

            Color statusColor = Colors.greenAccent;
            bool shouldBlink = false;
            if (limitDays <= 1) { statusColor = Colors.redAccent; shouldBlink = true; }
            else if (limitDays <= 3) { statusColor = Colors.orangeAccent; }

            return Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) => _consumeItem(index),
              background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30)),
              child: Card(
                color: Colors.black38,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
                  title: Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Row(children: [
                    const Text("あと ", style: TextStyle(color: Colors.white70)),
                    DropdownButton<double>(
                      value: currentVal > 50 ? 50 : currentVal,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold),
                      items: List.generate(51, (i) => i.toDouble()).map((val) => DropdownMenuItem(value: val, child: Text("${val.toInt()}"))).toList(),
                      onChanged: (v) => _updateItemCount(index, v!),
                    ),
                    Text(" ${item["unit"] ?? '個'}", style: const TextStyle(color: Colors.white70)),
                  ]),
                  trailing: AnimatedBuilder(
                    animation: _blinkController,
                    builder: (context, child) => Opacity(opacity: shouldBlink ? _blinkController.value : 1.0, child: Text(item["limit"], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // --- UI: 登録画面 ---
  Widget _buildAddView(Color textColor) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text(selectedIcon, style: const TextStyle(fontSize: 40))),
        const SizedBox(width: 20),
        Text("アイコン自動選択中", style: TextStyle(color: textColor.withOpacity(0.7))),
      ]),
      const SizedBox(height: 25),
      Text("📂 カテゴリ", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      DropdownButton<String>(
        value: _selectedCategory,
        isExpanded: true,
        dropdownColor: Colors.grey[900],
        style: TextStyle(color: textColor, fontSize: 18),
        items: _foodMaster.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
        onChanged: _onCategoryChanged,
      ),
      const SizedBox(height: 20),
      Text("📄 食材名", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      DropdownButton<String>(
        value: _selectedFoodName,
        isExpanded: true,
        dropdownColor: Colors.grey[900],
        style: TextStyle(color: textColor, fontSize: 18),
        items: _foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(value: f["name"] as String, child: Text(f["name"]))).toList(),
        onChanged: _onFoodChanged,
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: TextField(controller: _countController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "数量", labelStyle: TextStyle(color: textColor)))),
        const SizedBox(width: 10),
        DropdownButton<String>(value: _selectedUnit, dropdownColor: Colors.black87, style: TextStyle(color: textColor), items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _selectedUnit = v!)),
      ]),
      const SizedBox(height: 20),
      TextField(controller: _dateController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "賞味期限（あと何日？）", labelStyle: TextStyle(color: textColor))),
      const SizedBox(height: 40),
      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent), onPressed: () {
        setState(() {
          inventory.add({"name": _selectedFoodName, "icon": selectedIcon, "limit": "あと${_dateController.text}日", "count": double.tryParse(_countController.text) ?? 1.0, "unit": _selectedUnit});
        });
        _saveData(); setState(() => _currentTabIndex = 0);
      }, child: const Text("冒険の書に登録！", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))
    ]));
  }

  // --- 設定・買い物リスト ---
  void _showColorPicker() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text("背景色を選択", style: TextStyle(color: Colors.white)),
      content: SizedBox(width: double.maxFinite, child: GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8), itemCount: colorPalette.length, itemBuilder: (context, index) {
        return GestureDetector(onTap: () { setState(() => customColor = colorPalette[index]["color"]); _saveData(); Navigator.pop(context); }, child: Container(decoration: BoxDecoration(color: colorPalette[index]["color"], borderRadius: BorderRadius.circular(8))));
      })),
    ));
  }

  void _showSettings() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("システム設定"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(title: const Text("自動買い物登録"), value: autoShoppingAdd, onChanged: (v) { setState(() => autoShoppingAdd = v); _saveData(); Navigator.pop(context); }),
        ListTile(title: const Text("背景色を変更する"), trailing: CircleAvatar(backgroundColor: customColor, radius: 15), onTap: () { Navigator.pop(context); _showColorPicker(); }),
        ...List.generate(3, (i) => RadioListTile(value: i, groupValue: modeIndex, title: Text(charSettings[i]["name"]), onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(context); })),
      ]),
    ));
  }

  void _showShoppingList() {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("🛒 買い物リスト", style: TextStyle(color: Colors.white)),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...shoppingList.asMap().entries.map((e) => ListTile(
            leading: Text(e.value["icon"] ?? "📦"),
            title: Text(e.value["name"], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(icon: const Icon(Icons.check_box, color: Colors.green), onPressed: () { setState(() => shoppingList.removeAt(e.key)); _saveData(); setDialogState(() {}); }),
          )),
          const Divider(color: Colors.white24),
          const Text("🍴 最近の履歴", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ...recentlyConsumed.take(5).map((item) => ListTile(
            leading: Text(item["icon"] ?? "📦"),
            title: Text(item["name"], style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.add_shopping_cart, color: Colors.yellowAccent, size: 20),
            onTap: () { if (!shoppingList.any((s) => s["name"] == item["name"])) { setState(() => shoppingList.add(item)); _saveData(); setDialogState(() {}); } },
          )),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("閉じる"))],
      );
    }));
  }

  final List<Map<String, dynamic>> charSettings = [{"name": "🧓 長老"}, {"name": "🧑‍⚕️ 博士"}, {"name": "🕶️ 商人"}];
  void _speak(String text) { js.context.callMethod('eval', ["""window.speechSynthesis.cancel(); const uttr = new SpeechSynthesisUtterance('$text'); uttr.lang = 'ja-JP'; window.speechSynthesis.speak(uttr);"""]); }

  @override
  Widget build(BuildContext context) {
    Color textColor = customColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26,
        actions: [
          IconButton(onPressed: _showShoppingList, icon: Icon(Icons.shopping_cart, color: textColor)),
          IconButton(onPressed: _showSettings, icon: Icon(Icons.settings, color: textColor)),
        ],
      ),
      body: IndexedStack(index: _currentTabIndex, children: [
        _buildInventoryView(textColor),
        _buildAddView(textColor),
        const Center(child: Text("レシピ機能は準備中...", style: TextStyle(color: Colors.white54)))
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "冷蔵庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ"),
        ],
      ),
    );
  }
}