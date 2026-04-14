// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; // 外部データの読み込み

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

class _ReizokoAppState extends State<ReizokoApp> {
  int _currentTabIndex = 0;
  int modeIndex = 0;
  List<dynamic> inventory = [];     // 冷蔵庫の中身
  List<dynamic> shoppingHistory = []; // 買い物履歴（一度買ったもの）
  List<String> favoriteNames = [];  // お気に入り食材の名前リスト
  Color customColor = const Color(0xFF1B5E20);
  
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  String _searchQuery = "";
  final TextEditingController _customController = TextEditingController();

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。大事にするのじゃぞ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い。効率よく調理したまえ。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな。高く売れそうです！"},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- データの保存と読み込み ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      shoppingHistory = jsonDecode(prefs.getString('history') ?? "[]");
      favoriteNames = prefs.getStringList('favorites') ?? [];
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('history', jsonEncode(shoppingHistory));
    await prefs.setStringList('favorites', favoriteNames);
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setInt('savedColor', customColor.value);
  }

  void _speak(String text) {
    js.context.callMethod('eval', ["""
      window.speechSynthesis.cancel();
      const uttr = new SpeechSynthesisUtterance('$text');
      uttr.lang = 'ja-JP';
      window.speechSynthesis.speak(uttr);
    """]);
  }

  // 冷蔵庫への登録処理（共通）
  void _addFoodToInventory(Map<String, dynamic> food, {String? customName}) {
    final name = customName ?? food["name"];
    final expiryDate = DateTime.now().add(Duration(days: food["limit"]));

    setState(() {
      inventory.add({
        "name": name,
        "icon": food["icon"],
        "expiry": expiryDate.toIso8601String(),
        "limit": food["limit"], // 履歴からの再利用時に必要
      });
      // 履歴に追加（重複排除）
      if (!shoppingHistory.any((e) => e["name"] == food["name"])) {
        shoppingHistory.add(food);
      }
    });
    _speak(charSettings[modeIndex]["msg"]);
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", style: TextStyle(color: textColor)),
        backgroundColor: Colors.black26,
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [_buildInventoryView(textColor), _buildAddView(textColor), _buildHistoryView(textColor)],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "探す"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "履歴"),
        ],
      ),
    );
  }

  // --- 1. 在庫一覧 ---
  Widget _buildInventoryView(Color textColor) {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, i) {
        final item = inventory[i];
        final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
        return Card(
          color: days < 0 ? Colors.red.withOpacity(0.4) : Colors.black26,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Text(item["icon"], style: const TextStyle(fontSize: 24)),
            title: Text(item["name"], style: TextStyle(color: textColor)),
            subtitle: Text(days < 0 ? "期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.7))),
            trailing: IconButton(icon: const Icon(Icons.done, color: Colors.greenAccent), onPressed: () {
              setState(() => inventory.removeAt(i));
              _saveData();
            }),
          ),
        );
      },
    );
  }

  // --- 2. 探す/登録（検索 & 2段階プルダウン & お気に入り） ---
  Widget _buildAddView(Color textColor) {
    // 検索フィルタリング
    List<Map<String, dynamic>> searchResults = [];
    foodMaster.forEach((cat, foods) {
      for (var f in foods) {
        if (f["name"].contains(_searchQuery)) searchResults.add({...f, "category": cat});
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "食材名で検索...",
              hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: textColor),
              filled: true,
              fillColor: Colors.black12,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isEmpty) ...[
            Text("▼ カテゴリから選ぶ", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: textColor),
              items: foodMaster.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() { _selectedCategory = v!; _selectedFoodName = foodMaster[v]![0]["name"]; }),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedFoodName,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: textColor),
              items: foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(value: f["name"] as String, child: Text("${f["icon"]} ${f["name"]}"))).toList(),
              onChanged: (v) => setState(() => _selectedFoodName = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(hintText: "名前をカスタム(任意)", hintStyle: TextStyle(color: textColor.withOpacity(0.5))),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.yellowAccent),
              onPressed: () {
                final food = foodMaster[_selectedCategory]!.firstWhere((e) => e["name"] == _selectedFoodName);
                _addFoodToInventory(food, customName: _customController.text.isNotEmpty ? _customController.text : null);
                _customController.clear();
                setState(() => _currentTabIndex = 0);
              },
              child: const Text("冷蔵庫に収納", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            Text("検索結果", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ...searchResults.map((f) {
              final isFav = favoriteNames.contains(f["name"]);
              return ListTile(
                leading: Text(f["icon"], style: const TextStyle(fontSize: 24)),
                title: Text(f["name"], style: TextStyle(color: textColor)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.orange),
                      onPressed: () {
                        setState(() => isFav ? favoriteNames.remove(f["name"]) : favoriteNames.add(f["name"]));
                        _saveData();
                      },
                    ),
                    ElevatedButton(onPressed: () => _addFoodToInventory(f), child: const Text("追加")),
                  ],
                ),
              );
            }).toList(),
          ]
        ],
      ),
    );
  }

  // --- 3. 履歴（お気に入り優先表示） ---
  Widget _buildHistoryView(Color textColor) {
    // お気に入りを上に持ってくる
    shoppingHistory.sort((a, b) {
      bool aFav = favoriteNames.contains(a["name"]);
      bool bFav = favoriteNames.contains(b["name"]);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });

    return shoppingHistory.isEmpty
        ? Center(child: Text("まだ履歴はありません", style: TextStyle(color: textColor)))
        : ListView.builder(
            itemCount: shoppingHistory.length,
            itemBuilder: (context, i) {
              final f = shoppingHistory[i];
              final isFav = favoriteNames.contains(f["name"]);
              return ListTile(
                leading: Text(f["icon"], style: const TextStyle(fontSize: 24)),
                title: Text(f["name"], style: TextStyle(color: textColor)),
                subtitle: isFav ? const Text("🌟 お気に入り", style: TextStyle(color: Colors.orange, fontSize: 12)) : null,
                trailing: ElevatedButton(onPressed: () => _addFoodToInventory(f), child: const Text("また買った")),
              );
            },
          );
  }

  // --- 設定ダイアログ ---
  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("アプリ設定"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("NPC選択"),
          ...List.generate(3, (i) => RadioListTile(
            title: Text(charSettings[i]["name"]),
            value: i,
            groupValue: modeIndex,
            onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); },
          )),
          const Divider(),
          ElevatedButton(onPressed: () => _showColorPicker(), child: const Text("背景色変更")),
        ],
      ),
    ));
  }

  void _showColorPicker() {
    Navigator.pop(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("背景色を選択"),
      content: Wrap(
        children: [const Color(0xFF1B5E20), const Color(0xFF0D47A1), const Color(0xFFB71C1C), Colors.black, Colors.brown].map((c) => GestureDetector(
          onTap: () { setState(() => customColor = c); _saveData(); Navigator.pop(ctx); },
          child: Container(width: 50, height: 50, color: c, margin: const EdgeInsets.all(4)),
        )).toList(),
      ),
    ));
  }
}