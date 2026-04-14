// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; 

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
  List<dynamic> inventory = [];     
  List<dynamic> shoppingHistory = []; 
  List<String> favoriteNames = [];  
  Color customColor = const Color(0xFF1B5E20);
  
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  String _searchQuery = "";
  int _inputCount = 1; 

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

  void _addFoodToInventory(Map<String, dynamic> food, {String? customName, int count = 1}) {
    final name = customName ?? food["name"];
    final expiryDate = DateTime.now().add(Duration(days: food["limit"]));
    setState(() {
      inventory.add({
        "name": name, "icon": food["icon"], "expiry": expiryDate.toIso8601String(),
        "limit": food["limit"], "count": count,
      });
      if (!shoppingHistory.any((e) => e["name"] == food["name"])) shoppingHistory.add(food);
    });
    _speak("${name}を${count}個追加しました。");
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    // 背景の明るさに応じて文字色を白か黒に自動変更
    Color textColor = customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [IconButton(icon: const Icon(Icons.palette), onPressed: _showColorPickerDialog)],
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

  // --- 在庫一覧 ---
  Widget _buildInventoryView(Color textColor) {
    return inventory.isEmpty
        ? Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)))
        : ListView.builder(
            itemCount: inventory.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final item = inventory[i];
              final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
              return Card(
                color: days < 0 ? Colors.red.withOpacity(0.4) : Colors.black26,
                child: ListTile(
                  leading: Text(item["icon"], style: const TextStyle(fontSize: 26)),
                  title: Text("${item["name"]} × ${item["count"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  subtitle: Text(days < 0 ? "期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.7))),
                  trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent),
                    onPressed: () { setState(() { if (item["count"] > 1) { inventory[i]["count"]--; } else { inventory.removeAt(i); } }); _saveData(); },
                  ),
                ),
              );
            },
          );
  }

  // --- 登録・検索 ---
  Widget _buildAddView(Color textColor) {
    List<Map<String, dynamic>> searchResults = [];
    foodMaster.forEach((cat, foods) {
      for (var f in foods) { if (f["name"].contains(_searchQuery)) searchResults.add({...f, "category": cat}); }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            style: TextStyle(color: textColor),
            decoration: InputDecoration(hintText: "食材を検索...", prefixIcon: Icon(Icons.search, color: textColor), filled: true, fillColor: Colors.black12),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isEmpty) ...[
            _buildCounter(textColor),
            DropdownButton<String>(
              value: _selectedCategory, isExpanded: true, dropdownColor: Colors.grey[900], style: TextStyle(color: textColor),
              items: foodMaster.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() { _selectedCategory = v!; _selectedFoodName = foodMaster[v]![0]["name"]; }),
            ),
            DropdownButton<String>(
              value: _selectedFoodName, isExpanded: true, dropdownColor: Colors.grey[900], style: TextStyle(color: textColor),
              items: foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(value: f["name"] as String, child: Text("${f["icon"]} ${f["name"]}"))).toList(),
              onChanged: (v) => setState(() => _selectedFoodName = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.yellowAccent),
              onPressed: () {
                final f = foodMaster[_selectedCategory]!.firstWhere((e) => e["name"] == _selectedFoodName);
                _addFoodToInventory(f, count: _inputCount);
                setState(() { _inputCount = 1; _currentTabIndex = 0; });
              },
              child: const Text("登録する", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            ...searchResults.map((f) => ListTile(
              leading: Text(f["icon"], style: const TextStyle(fontSize: 24)),
              title: Text(f["name"], style: TextStyle(color: textColor)),
              trailing: ElevatedButton(onPressed: () => _showCountDialog(f), child: const Text("追加")),
            )),
          ]
        ],
      ),
    );
  }

  // --- 履歴 ---
  Widget _buildHistoryView(Color textColor) {
    return shoppingHistory.isEmpty ? Center(child: Text("履歴なし", style: TextStyle(color: textColor))) : ListView.builder(
      itemCount: shoppingHistory.length,
      itemBuilder: (context, i) => ListTile(
        leading: Text(shoppingHistory[i]["icon"], style: const TextStyle(fontSize: 24)),
        title: Text(shoppingHistory[i]["name"], style: TextStyle(color: textColor)),
        trailing: ElevatedButton(onPressed: () => _showCountDialog(shoppingHistory[i]), child: const Text("また買った")),
      ),
    );
  }

  Widget _buildCounter(Color textColor) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("個数: ", style: TextStyle(color: textColor, fontSize: 18)),
      IconButton(icon: Icon(Icons.remove_circle, color: textColor), onPressed: () => setState(() { if(_inputCount > 1) _inputCount--; })),
      Text("$_inputCount", style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
      IconButton(icon: Icon(Icons.add_circle, color: textColor), onPressed: () => setState(() => _inputCount++)),
    ]);
  }

  void _showCountDialog(Map<String, dynamic> food) {
    int temp = 1;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text("${food["name"]}の個数"),
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.remove), onPressed: () => setS(() { if(temp > 1) temp--; })),
        Text("$temp", style: const TextStyle(fontSize: 28)),
        IconButton(icon: const Icon(Icons.add), onPressed: () => setS(() => temp++)),
      ]),
      actions: [ElevatedButton(onPressed: () { _addFoodToInventory(food, count: temp); Navigator.pop(ctx); setState(() => _currentTabIndex = 0); }, child: const Text("追加"))],
    )));
  }

  // --- 背景色選択ダイアログ (プリセット + カスタム) ---
  void _showColorPickerDialog() {
    final List<Color> presets = [
      const Color(0xFF1B5E20), const Color(0xFFB71C1C), const Color(0xFF0D47A1),
      const Color(0xFF4A148C), const Color(0xFFE65100), Colors.black,
      Colors.brown, Colors.teal, Colors.blueGrey, Colors.indigo,
      const Color(0xFFD81B60), const Color(0xFF00695C),
    ];

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("背景デザイン設定"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("プリセットから選ぶ"),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: presets.map((c) => GestureDetector(
                onTap: () { setState(() => customColor = c); _saveData(); Navigator.pop(ctx); },
                child: Container(width: 45, height: 45, decoration: BoxDecoration(color: c, border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(8))),
              )).toList(),
            ),
            const Divider(height: 30),
            const Text("好きな色を作る"),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.colorize),
              label: const Text("自由な色を選択"),
              onPressed: () async {
                Navigator.pop(ctx);
                // ブラウザのカラーピッカーを呼び出す
                final result = await js.context.callMethod('eval', ["""
                  new Promise((resolve) => {
                    const input = document.createElement('input');
                    input.type = 'color';
                    input.onchange = () => resolve(input.value);
                    input.click();
                  });
                """]);
                if (result != null) {
                  String hex = result.toString().replaceFirst('#', '');
                  setState(() { customColor = Color(int.parse("FF$hex", radix: 16)); });
                  _saveData();
                }
              },
            ),
            const Divider(height: 30),
            const Text("キャラクター"),
            ...List.generate(3, (i) => RadioListTile(
              title: Text(charSettings[i]["name"]), value: i, groupValue: modeIndex,
              onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); },
            )),
          ],
        ),
      ),
    ));
  }
}