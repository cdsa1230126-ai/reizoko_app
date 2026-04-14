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

class _ReizokoAppState extends State<ReizokoApp> {
  int _currentTabIndex = 0;
  int modeIndex = 0;
  List<dynamic> inventory = [];
  Color customColor = const Color(0xFF1B5E20);

  // 選択用変数
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  String _selectedUnit = "g";
  int _limitDays = 3;
  double _inputCount = 1.0;

  // --- 食材マスタ (2段プルダウン用 & アイコン定義) ---
  final Map<String, List<Map<String, dynamic>>> foodMaster = {
    "肉類": [
      {"name": "鶏むね肉", "icon": "🍗", "limit": 2, "unit": "g"},
      {"name": "豚バラ肉", "icon": "🥩", "limit": 3, "unit": "g"},
      {"name": "牛肉", "icon": "🍖", "limit": 3, "unit": "g"},
      {"name": "ひき肉", "icon": "🥩", "limit": 2, "unit": "g"},
    ],
    "野菜": [
      {"name": "キャベツ", "icon": "🥬", "limit": 7, "unit": "個"},
      {"name": "たまねぎ", "icon": "🧅", "limit": 21, "unit": "個"},
      {"name": "にんじん", "icon": "🥕", "limit": 14, "unit": "本"},
      {"name": "じゃがいも", "icon": "🥔", "limit": 30, "unit": "個"},
      {"name": "トマト", "icon": "🍅", "limit": 5, "unit": "個"},
    ],
    "主食": [
      {"name": "お米", "icon": "🌾", "limit": 180, "unit": "kg"},
      {"name": "食パン", "icon": "🍞", "limit": 5, "unit": "枚"},
      {"name": "麺類", "icon": "🍜", "limit": 5, "unit": "個"},
    ],
    "乳製品・卵": [
      {"name": "卵", "icon": "🥚", "limit": 14, "unit": "個"},
      {"name": "牛乳", "icon": "🥛", "limit": 5, "unit": "ml"},
      {"name": "チーズ", "icon": "🧀", "limit": 14, "unit": "個"},
      {"name": "ヨーグルト", "icon": "🍦", "limit": 7, "unit": "個"},
    ],
    "調味料・他": [
      {"name": "焼肉のタレ", "icon": "🍯", "limit": 90, "unit": "個"},
      {"name": "ジュース", "icon": "🧃", "limit": 3, "unit": "個"},
      {"name": "プリン", "icon": "🍮", "limit": 2, "unit": "個"},
      {"name": "納豆", "icon": "🥢", "limit": 7, "unit": "パック"},
    ],
  };

  final List<String> unitOptions = ["個", "g", "kg", "ml", "本", "枚", "パック", "合"];

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな！"},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFieldsFromMaster("鶏むね肉");
  }

  void _updateFieldsFromMaster(String foodName) {
    for (var cat in foodMaster.values) {
      for (var item in cat) {
        if (item["name"] == foodName) {
          setState(() {
            _selectedUnit = item["unit"];
            _limitDays = item["limit"];
          });
          return;
        }
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setInt('savedColor', customColor.value);
  }

  void _addFood() {
    double step = (_selectedFoodName.contains("米") || _selectedUnit == "kg") ? 0.15 : 1.0;
    final expiryDate = DateTime.now().add(Duration(days: _limitDays));

    setState(() {
      inventory.add({
        "name": _selectedFoodName,
        "icon": _getIcon(_selectedFoodName),
        "expiry": expiryDate.toIso8601String(),
        "count": _inputCount,
        "unit": _selectedUnit,
        "step": step,
      });
    });

    _speak("${charSettings[modeIndex]["msg"]} $_selectedFoodNameを入れたぞ。");
    _saveData();
    setState(() {
      _currentTabIndex = 0;
      _inputCount = 1.0;
    });
  }

  String _getIcon(String name) {
    for (var cat in foodMaster.values) {
      for (var item in cat) { if (item["name"] == name) return item["icon"]; }
    }
    return "📦";
  }

  void _speak(String text) {
    js.context.callMethod('eval', ["""window.speechSynthesis.cancel(); const uttr = new SpeechSynthesisUtterance('$text'); uttr.lang = 'ja-JP'; window.speechSynthesis.speak(uttr);"""]);
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.palette), onPressed: _showSettingsDialog)],
      ),
      body: _currentTabIndex == 0 ? _buildInventoryView(textColor) : _buildAddView(textColor),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: "登録"),
        ],
      ),
    );
  }

  // --- 1. 在庫一覧 (グレーの空白を完全に排除) ---
  Widget _buildInventoryView(Color textColor) {
    return inventory.isEmpty
        ? Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)))
        : ListView.builder(
            itemCount: inventory.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final item = inventory[i];
              final count = (item["count"] ?? 0).toDouble();
              final step = (item["step"] ?? 1.0).toDouble();
              final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
              String displayCount = (count == count.toInt()) ? count.toInt().toString() : count.toStringAsFixed(2);
              String minusLabel = (item["name"].contains("米") || item["unit"] == "kg") ? "1合使う" : "1${item["unit"]}使う";

              return Card(
                color: days < 0 ? Colors.red.withOpacity(0.5) : Colors.black26,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 32)),
                  title: Text("${item["name"]} × $displayCount ${item["unit"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(days < 0 ? "期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.8))),
                  trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.remove_circle, color: Colors.orangeAccent, size: 28),
                      onPressed: () { setState(() { if (count > step + 0.001) { inventory[i]["count"] = count - step; } else { inventory.removeAt(i); } }); _saveData(); },
                    ),
                    Text(minusLabel, style: TextStyle(color: textColor, fontSize: 10)),
                  ]),
                ),
              );
            },
          );
  }

  // --- 2. 登録画面 (2段プルダウン & 単位プルダウン) ---
  Widget _buildAddView(Color textColor) {
    List<String> foodOptions = foodMaster[_selectedCategory]!.map((e) => e["name"] as String).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // カテゴリー選択プルダウン
        _buildDropdown("① カテゴリーを選ぶ", foodMaster.keys.toList(), _selectedCategory, (v) {
          setState(() {
            _selectedCategory = v!;
            _selectedFoodName = foodMaster[v]![0]["name"];
            _updateFieldsFromMaster(_selectedFoodName);
          });
        }),
        const SizedBox(height: 20),
        // 食材選択プルダウン
        _buildDropdown("② 食材を選ぶ", foodOptions, _selectedFoodName, (v) {
          setState(() { _selectedFoodName = v!; _updateFieldsFromMaster(v); });
        }),
        const SizedBox(height: 20),
        // 単位選択プルダウン (復活!)
        _buildDropdown("③ 単位を選ぶ", unitOptions, _selectedUnit, (v) => setState(() => _selectedUnit = v!)),
        const SizedBox(height: 20),
        // 賞味期限入力
        TextField(
          controller: TextEditingController(text: _limitDays.toString()),
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor),
          onChanged: (v) => _limitDays = int.tryParse(v) ?? 3,
          decoration: InputDecoration(labelText: "賞味期限 (日)", labelStyle: TextStyle(color: textColor), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor))),
        ),
        const SizedBox(height: 40),
        // 個数調整
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: Icon(Icons.remove_circle_outline, color: textColor, size: 45), onPressed: () => setState(() { if(_inputCount > 1) _inputCount--; })),
          const SizedBox(width: 20),
          Text("${_inputCount.toInt()}", style: TextStyle(color: textColor, fontSize: 50, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          IconButton(icon: Icon(Icons.add_circle_outline, color: textColor, size: 45), onPressed: () => setState(() => _inputCount++)),
        ]),
        const SizedBox(height: 50),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 65), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          onPressed: _addFood,
          child: const Text("冷蔵庫に保管する", style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black12),
      dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white, fontSize: 18),
    );
  }

  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900], title: const Text("設定", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(3, (i) => RadioListTile(title: Text(charSettings[i]["name"], style: const TextStyle(color: Colors.white)), value: i, groupValue: modeIndex, onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); })),
        const Divider(color: Colors.white24),
        TextButton.icon(icon: const Icon(Icons.colorize, color: Colors.yellowAccent), label: const Text("背景色を変える", style: TextStyle(color: Colors.yellowAccent)), 
          onPressed: () async { Navigator.pop(ctx); final result = await js.context.callMethod('eval', ["""new Promise((resolve) => { const input = document.createElement('input'); input.type = 'color'; input.onchange = () => resolve(input.value); input.click(); });"""]); if (result != null) { String hex = result.toString().replaceFirst('#', ''); setState(() { customColor = Color(int.parse("FF$hex", radix: 16)); }); _saveData(); } }),
      ]),
    ));
  }
}