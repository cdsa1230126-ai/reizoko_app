// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: ReizokoApp(),
    debugShowCheckedModeBanner: false,
  ));
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
  Color customColor = const Color(0xFF1B5E20);
  String recipeApiKey = "";

  // --- 劇的に拡張した食材マスタ (世界中の詳細な食材に対応) ---
  final Map<String, List<Map<String, dynamic>>> _foodMaster = {
    "鶏肉": [
      {"name": "鶏むね肉", "icon": "🍗", "limit": 2},
      {"name": "鶏もも肉", "icon": "🍗", "limit": 2},
      {"name": "ささみ", "icon": "🍗", "limit": 2},
      {"name": "手羽先", "icon": "🍗", "limit": 2},
      {"name": "鶏ひき肉", "icon": "🥩", "limit": 1},
    ],
    "豚肉": [
      {"name": "豚バラ肉", "icon": "🥩", "limit": 3},
      {"name": "豚ロース", "icon": "🥩", "limit": 3},
      {"name": "豚こま切れ", "icon": "🥩", "limit": 3},
      {"name": "豚ひき肉", "icon": "🥩", "limit": 2},
    ],
    "牛肉": [
      {"name": "牛サーロイン", "icon": "🥩", "limit": 3},
      {"name": "牛もも肉", "icon": "🥩", "limit": 3},
      {"name": "牛バラ肉", "icon": "🥩", "limit": 3},
      {"name": "牛ひき肉", "icon": "🥩", "limit": 2},
    ],
    "魚介類": [
      {"name": "サーモン", "icon": "🐟", "limit": 2},
      {"name": "真鯛", "icon": "🐟", "limit": 2},
      {"name": "マグロ赤身", "icon": "🍣", "limit": 1},
      {"name": "鯖", "icon": "🐟", "limit": 3},
      {"name": "むきエビ", "icon": "🦐", "limit": 3},
      {"name": "ホタテ", "icon": "🐚", "limit": 2},
    ],
    "野菜・果物": [
      {"name": "キャベツ", "icon": "🥬", "limit": 7},
      {"name": "玉ねぎ", "icon": "🧅", "limit": 21},
      {"name": "アボカド", "icon": "🥑", "limit": 5},
      {"name": "ブロッコリー", "icon": "🥦", "limit": 4},
      {"name": "パクチー", "icon": "🌿", "limit": 3},
      {"name": "パプリカ", "icon": "🫑", "limit": 7},
    ],
    "世界・加工品": [
      {"name": "生ハム", "icon": "🥓", "limit": 10},
      {"name": "モッツァレラ", "icon": "🧀", "limit": 7},
      {"name": "キムチ", "icon": "🌶️", "limit": 14},
      {"name": "ココナッツミルク", "icon": "🥥", "limit": 30},
      {"name": "ソーセージ", "icon": "🌭", "limit": 10},
    ],
  };

  String _selectedCategory = "鶏肉";
  String _selectedFoodName = "鶏むね肉";
  final TextEditingController _customFoodController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: "1");
  String _selectedUnit = "個";

  // --- 自動テキストカラー調整ロジック (修正版) ---
  Color get _dynamicTextColor =>
      customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      recipeApiKey = prefs.getString('recipeApiKey') ?? "";
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('recipeApiKey', recipeApiKey);
    await prefs.setInt('savedColor', customColor.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("魔法の冷蔵庫", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26,
        elevation: 0,
        iconTheme: IconThemeData(color: _dynamicTextColor),
        actions: [
          IconButton(
            icon: Icon(Icons.palette, color: _dynamicTextColor),
            onPressed: _showColorPicker,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildInventoryView(),
          _buildAddView(),
          _buildRecipeSettingView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AI提案"),
        ],
      ),
    );
  }

  // --- 1. 在庫一覧画面 ---
  Widget _buildInventoryView() {
    if (inventory.isEmpty) {
      return Center(child: Text("庫内が空っぽじゃ...", style: TextStyle(color: _dynamicTextColor, fontSize: 18)));
    }
    return ListView.builder(
      itemCount: inventory.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final item = inventory[index];
        return Card(
          color: Colors.black38,
          child: ListTile(
            leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
            title: Text(item["name"], style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
            subtitle: Text("${item["count"]} ${item["unit"]} | ${item["limit"]}", style: TextStyle(color: _dynamicTextColor.withOpacity(0.7))),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => setState(() { inventory.removeAt(index); _saveData(); }),
            ),
          ),
        );
      },
    );
  }

  // --- 2. 食材登録画面 (世界中の食材・自由入力対応) ---
  Widget _buildAddView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("1. カテゴリ選択"),
          DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            dropdownColor: Colors.grey[900],
            style: TextStyle(color: _dynamicTextColor, fontSize: 18),
            items: _foodMaster.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() {
              _selectedCategory = v!;
              _selectedFoodName = _foodMaster[v]![0]["name"];
            }),
          ),
          const SizedBox(height: 20),
          _label("2. 食材名 (詳細)"),
          DropdownButton<String>(
            value: _selectedFoodName,
            isExpanded: true,
            dropdownColor: Colors.grey[900],
            style: TextStyle(color: _dynamicTextColor, fontSize: 18),
            items: _foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(value: f["name"] as String, child: Text(f["name"]))).toList(),
            onChanged: (v) => setState(() => _selectedFoodName = v!),
          ),
          const SizedBox(height: 15),
          Text("または自由に入力（世界中の食材に対応！）", style: TextStyle(color: _dynamicTextColor.withOpacity(0.6), fontSize: 12)),
          TextField(
            controller: _customFoodController,
            style: TextStyle(color: _dynamicTextColor),
            decoration: InputDecoration(
              hintText: "例：ワニ肉、トリュフ、秘密のスパイス",
              hintStyle: TextStyle(color: _dynamicTextColor.withOpacity(0.3)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _dynamicTextColor)),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, minimumSize: const Size(double.infinity, 55)),
            onPressed: () {
              final finalName = _customFoodController.text.isNotEmpty ? _customFoodController.text : _selectedFoodName;
              final foodData = _foodMaster[_selectedCategory]?.firstWhere((e) => e["name"] == _selectedFoodName, orElse: () => {"icon": "📦", "limit": 3});
              setState(() {
                inventory.add({
                  "name": finalName,
                  "icon": foodData!["icon"],
                  "count": _countController.text,
                  "unit": "個",
                  "limit": "あと${foodData["limit"]}日"
                });
              });
              _customFoodController.clear();
              _saveData();
              setState(() => _currentTabIndex = 0);
            },
            child: const Text("冒険の書に登録！", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- 3. AIレシピ設定画面 (API初心者向けガイド付き) ---
  Widget _buildRecipeSettingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, size: 60, color: _dynamicTextColor),
          const SizedBox(height: 16),
          Text("AIレシピ提案を解禁する", style: TextStyle(color: _dynamicTextColor, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Text(
              "冷蔵庫にある食材から、AIがあなただけのレシピを提案します。これにはOpenAIというサービスの「魔法の鍵（APIキー）」が必要です。",
              style: TextStyle(color: _dynamicTextColor),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: TextEditingController(text: recipeApiKey),
            obscureText: true,
            style: TextStyle(color: _dynamicTextColor),
            decoration: InputDecoration(
              labelText: "魔法の鍵 (API Key) を入力",
              labelStyle: TextStyle(color: _dynamicTextColor),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _dynamicTextColor)),
            ),
            onChanged: (v) { recipeApiKey = v; _saveData(); },
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.help_outline),
            label: const Text("鍵の入手方法を教えて（初心者向けガイド）"),
            onPressed: () => js.context.callMethod('open', ['https://platform.openai.com/api-keys']),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)));

  void _showColorPicker() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("背景色を選んでください"),
      content: Wrap(
        children: [Colors.red, Colors.blue, Colors.green, Colors.black, Colors.purple, Colors.orange].map((c) => GestureDetector(
          onTap: () { setState(() => customColor = c); _saveData(); Navigator.pop(ctx); },
          child: Container(width: 50, height: 50, color: c, margin: const EdgeInsets.all(4)),
        )).toList(),
      ),
    ));
  }
}