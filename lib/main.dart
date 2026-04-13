// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // エラーを避けるため、既存のMyAppではなくReizokoAppを直接起動します
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

  // 楽天レシピ検索用URL
  final String recipeSearchBaseUrl = "https://recipe.rakuten.co.jp/search/";

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
    ],
    "野菜・果物": [
      {"name": "キャベツ", "icon": "🥬", "limit": 7},
      {"name": "レタス", "icon": "🥗", "limit": 4},
      {"name": "トマト", "icon": "🍅", "limit": 5},
      {"name": "玉ねぎ", "icon": "🧅", "limit": 21},
      {"name": "人参", "icon": "🥕", "limit": 14},
      {"name": "じゃがいも", "icon": "🥔", "limit": 30},
    ],
    "乳製品・卵": [
      {"name": "牛乳", "icon": "🥛", "limit": 5},
      {"name": "卵", "icon": "🥚", "limit": 14},
      {"name": "チーズ", "icon": "🧀", "limit": 30},
    ],
    "主食・その他": [
      {"name": "米", "icon": "🍚", "limit": 365},
      {"name": "パン", "icon": "🍞", "limit": 3},
      {"name": "豆腐", "icon": "⬜", "limit": 3},
      {"name": "納豆", "icon": "🍱", "limit": 7},
    ],
  };

  String _selectedCategory = "肉類";
  String _selectedFoodName = "牛肉";
  String selectedIcon = "🥩";

  // 背景色パレット (元の膨大なリストを保持)
  final List<Map<String, dynamic>> colorPalette = [
    {"name": "IndianRed", "color": const Color(0xFFCD5C5C)},
    {"name": "Salmon", "color": const Color(0xFFFA8072)},
    {"name": "Crimson", "color": const Color(0xFFDC143C)},
    {"name": "DeepPink", "color": const Color(0xFFFF1493)},
    {"name": "Coral", "color": const Color(0xFFFF7F50)},
    {"name": "Orange", "color": const Color(0xFFFFA500)},
    {"name": "Gold", "color": const Color(0xFFFFD700)},
    {"name": "Yellow", "color": const Color(0xFFFFFF00)},
    {"name": "ForestGreen", "color": const Color(0xFF228B22)},
    {"name": "Teal", "color": const Color(0xFF008080)},
    {"name": "Navy", "color": const Color(0xFF233B6C)},
    {"name": "Black", "color": const Color(0xFF000000)},
    {"name": "山吹色", "color": const Color(0xFFF8B400)},
    {"name": "真紅", "color": const Color(0xFFB13546)},
  ];

  final TextEditingController _dateController = TextEditingController(text: "3");
  final TextEditingController _countController = TextEditingController(text: "1");
  String _selectedUnit = "個";
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋"];

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

  // --- レシピ検索 (JSで別窓を開く) ---
  void _openRecipeSearch(String keyword) {
    final url = "$recipeSearchBaseUrl$keyword/";
    js.context.callMethod('open', [url]);
    _speak("${keyword}のレシピを探してきたぞ！");
  }

  // --- 保存・読み込み ---
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

  // --- プルダウン連動 ---
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

  // --- 各画面のビルド ---
  Widget _buildInventoryView(Color textColor) {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final limitDays = int.tryParse(item["limit"].replaceAll(RegExp(r'[^0-9]'), '')) ?? 99;
        bool shouldBlink = limitDays <= 1;

        return Dismissible(
          key: UniqueKey(),
          onDismissed: (dir) => _consumeItem(index),
          background: Container(color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
          child: Card(
            color: Colors.black38,
            child: ListTile(
              leading: Text(item["icon"], style: const TextStyle(fontSize: 28)),
              title: Text(item["name"], style: const TextStyle(color: Colors.white)),
              subtitle: Text("あと ${item["count"]} ${item["unit"]}", style: const TextStyle(color: Colors.white70)),
              trailing: AnimatedBuilder(
                animation: _blinkController,
                builder: (ctx, child) => Opacity(opacity: shouldBlink ? _blinkController.value : 1.0, 
                child: Text(item["limit"], style: TextStyle(color: shouldBlink ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddView(Color textColor) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("📄 カテゴリ", style: TextStyle(color: textColor)),
      DropdownButton<String>(
        value: _selectedCategory,
        isExpanded: true,
        dropdownColor: Colors.grey[900],
        style: TextStyle(color: textColor, fontSize: 18),
        items: _foodMaster.keys.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
        onChanged: _onCategoryChanged,
      ),
      const SizedBox(height: 15),
      Text("🥩 具体的な食材", style: TextStyle(color: textColor)),
      DropdownButton<String>(
        value: _selectedFoodName,
        isExpanded: true,
        dropdownColor: Colors.grey[900],
        style: TextStyle(color: textColor, fontSize: 18),
        items: _foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(value: f["name"] as String, child: Text(f["name"]))).toList(),
        onChanged: _onFoodChanged,
      ),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: TextField(controller: _countController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "数", labelStyle: TextStyle(color: textColor)))),
        const SizedBox(width: 10),
        DropdownButton<String>(value: _selectedUnit, dropdownColor: Colors.black87, style: TextStyle(color: textColor), items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _selectedUnit = v!)),
      ]),
      const SizedBox(height: 30),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, minimumSize: const Size(double.infinity, 50)),
        onPressed: () {
          setState(() => inventory.add({"name": _selectedFoodName, "icon": selectedIcon, "limit": "あと${_dateController.text}日", "count": _countController.text, "unit": _selectedUnit}));
          _saveData(); setState(() => _currentTabIndex = 0);
        },
        child: const Text("冒険の書に登録！", style: TextStyle(color: Colors.black)),
      )
    ]));
  }

  Widget _buildRecipeView(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text("庫内が空っぽじゃ...", style: TextStyle(color: textColor)));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text("📜 在庫でおすすめ検索", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...inventory.map((item) => Card(color: Colors.black26, child: ListTile(
        leading: Text(item["icon"]),
        title: Text(item["name"], style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.search, color: Colors.yellowAccent),
        onTap: () => _openRecipeSearch(item["name"]),
      ))),
    ]);
  }

  // --- 設定ダイアログ等 ---
  void _showColorPicker() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("背景色", style: TextStyle(color: Colors.white)),
      content: SizedBox(width: double.maxFinite, child: GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4), itemCount: colorPalette.length, itemBuilder: (ctx, i) {
        return GestureDetector(onTap: () { setState(() => customColor = colorPalette[i]["color"]); _saveData(); Navigator.pop(ctx); }, child: Container(margin: const EdgeInsets.all(4), color: colorPalette[i]["color"]));
      })),
    ));
  }

  final List<Map<String, dynamic>> charSettings = [{"name": "🧓 長老"}, {"name": "🧑‍⚕️ 博士"}, {"name": "🕶️ 商人"}];
  void _speak(String text) { js.context.callMethod('eval', ["""window.speechSynthesis.cancel(); const uttr = new SpeechSynthesisUtterance('$text'); uttr.lang = 'ja-JP'; window.speechSynthesis.speak(uttr);"""]); }

  @override
  Widget build(BuildContext context) {
    Color textColor = customColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫"), backgroundColor: Colors.black26, actions: [
        IconButton(icon: const Icon(Icons.settings), onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("設定"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: const Text("色を変える"), onTap: () { Navigator.pop(ctx); _showColorPicker(); }),
            ...List.generate(3, (i) => RadioListTile(value: i, groupValue: modeIndex, title: Text(charSettings[i]["name"]), onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); })),
          ]),
        ))),
      ]),
      body: IndexedStack(index: _currentTabIndex, children: [_buildInventoryView(textColor), _buildAddView(textColor), _buildRecipeView(textColor)]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white54,
        items: const [BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "冷蔵庫"), BottomNavigationBarItem(icon: Icon(Icons.add), label: "登録"), BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ")],
      ),
    );
  }
}