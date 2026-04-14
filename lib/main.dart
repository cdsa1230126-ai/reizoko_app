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
  List<dynamic> userMaster = []; 
  Color customColor = const Color(0xFF1B5E20);
  
  // 入力制御
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  bool _isManualInput = false;

  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: "g");
  final TextEditingController _limitController = TextEditingController(text: "2");
  double _inputCount = 1.0;

  // --- 初期マスタデータ ---
  final Map<String, List<Map<String, dynamic>>> foodMaster = {
    "肉類": [
      {"name": "鶏むね肉", "icon": "🍗", "limit": 2, "unit": "g"},
      {"name": "豚バラ肉", "icon": "🥩", "limit": 3, "unit": "g"},
    ],
    "野菜": [
      {"name": "キャベツ", "icon": "🥬", "limit": 7, "unit": "個"},
      {"name": "たまねぎ", "icon": "🧅", "limit": 21, "unit": "個"},
    ],
    "主食": [
      {"name": "お米", "icon": "🌾", "limit": 180, "unit": "kg"},
      {"name": "食パン", "icon": "🍞", "limit": 5, "unit": "枚"},
    ],
    "乳製品・卵": [
      {"name": "卵", "icon": "🥚", "limit": 14, "unit": "個"},
      {"name": "牛乳", "icon": "🥛", "limit": 5, "unit": "ml"},
    ],
  };

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな！"},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFieldsFromMaster("鶏むね肉"); // 初期値セット
  }

  // マスターから単位や期限を自動セット
  void _updateFieldsFromMaster(String foodName) {
    if (foodName == "＋新規登録") {
      setState(() { _isManualInput = true; _unitController.text = "個"; _limitController.text = "3"; });
      return;
    }
    _isManualInput = false;
    for (var cat in foodMaster.values) {
      for (var item in cat) {
        if (item["name"] == foodName) {
          setState(() {
            _unitController.text = item["unit"];
            _limitController.text = item["limit"].toString();
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
    String name = _isManualInput ? _manualNameController.text : _selectedFoodName;
    if (name.isEmpty) return;

    double step = (name.contains("米") || _unitController.text == "kg") ? 0.15 : 1.0;
    final expiryDate = DateTime.now().add(Duration(days: int.tryParse(_limitController.text) ?? 3));

    setState(() {
      inventory.add({
        "name": name,
        "expiry": expiryDate.toIso8601String(),
        "count": _inputCount,
        "unit": _unitController.text,
        "step": step,
        "icon": _isManualInput ? "📦" : _getIcon(name),
      });
    });

    _speak("${charSettings[modeIndex]["msg"]} $nameを入れたぞ。");
    _manualNameController.clear();
    _inputCount = 1.0;
    _saveData();
    setState(() => _currentTabIndex = 0);
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

              return Card(
                color: days < 0 ? Colors.red.withOpacity(0.5) : Colors.black26,
                child: ListTile(
                  leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 30)),
                  title: Text("${item["name"]} × $displayCount ${item["unit"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  subtitle: Text(days < 0 ? "期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.7))),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.orangeAccent),
                    onPressed: () { setState(() { if (count > step + 0.001) { inventory[i]["count"] = count - step; } else { inventory.removeAt(i); } }); _saveData(); },
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAddView(Color textColor) {
    List<String> foodOptions = (foodMaster[_selectedCategory] ?? []).map((e) => e["name"] as String).toList();
    foodOptions.add("＋新規登録");

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // カテゴリー選択
        _buildDropdown("カテゴリー", foodMaster.keys.toList(), _selectedCategory, (v) {
          setState(() {
            _selectedCategory = v!;
            _selectedFoodName = (foodMaster[v]![0]["name"]);
            _updateFieldsFromMaster(_selectedFoodName);
          });
        }),
        const SizedBox(height: 20),
        // 食材選択プルダウン
        _buildDropdown("食材", foodOptions, _selectedFoodName, (v) {
          setState(() { _selectedFoodName = v!; _updateFieldsFromMaster(v); });
        }),
        if (_isManualInput) ...[
          const SizedBox(height: 20),
          TextField(controller: _manualNameController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "新しい食材名", labelStyle: TextStyle(color: textColor), filled: true, fillColor: Colors.black12)),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextField(controller: _unitController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "単位", labelStyle: TextStyle(color: textColor)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _limitController, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "期限(日)", labelStyle: TextStyle(color: textColor)))),
        ]),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: Icon(Icons.remove_circle_outline, color: textColor, size: 40), onPressed: () => setState(() { if(_inputCount > 1) _inputCount--; })),
          Text("  ${_inputCount.toInt()}  ", style: TextStyle(color: textColor, fontSize: 40, fontWeight: FontWeight.bold)),
          IconButton(icon: Icon(Icons.add_circle_outline, color: textColor, size: 40), onPressed: () => setState(() => _inputCount++)),
        ]),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.yellowAccent),
          onPressed: _addFood,
          child: const Text("登録する", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70)),
      dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white),
    );
  }

  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900], title: const Text("アプリ設定", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(3, (i) => RadioListTile(title: Text(charSettings[i]["name"], style: const TextStyle(color: Colors.white)), value: i, groupValue: modeIndex, onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); })),
        const Divider(color: Colors.white24),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          final result = await js.context.callMethod('eval', ["""new Promise((resolve) => { const input = document.createElement('input'); input.type = 'color'; input.onchange = () => resolve(input.value); input.click(); });"""]);
          if (result != null) { String hex = result.toString().replaceFirst('#', ''); setState(() { customColor = Color(int.parse("FF$hex", radix: 16)); }); _saveData(); }
        }, child: const Text("背景色を選択")),
      ]),
    ));
  }
}