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
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: "個");
  final TextEditingController _limitController = TextEditingController(text: "3");
  String _selectedCategory = "その他";
  double _inputCount = 1.0;

  // --- 拡張版：標準食材マスタ ---
  final List<Map<String, dynamic>> defaultMaster = [
    {"name": "お米", "unit": "kg", "limit": 180, "icon": "🌾", "cat": "主食"},
    {"name": "鶏むね肉", "unit": "g", "limit": 2, "icon": "🍗", "cat": "肉類"},
    {"name": "豚バラ肉", "unit": "g", "limit": 3, "icon": "🥩", "cat": "肉類"},
    {"name": "たまねぎ", "unit": "個", "limit": 21, "icon": "🧅", "cat": "野菜"},
    {"name": "卵", "unit": "個", "limit": 14, "icon": "🥚", "cat": "乳製品"},
    {"name": "牛乳", "unit": "ml", "limit": 5, "icon": "🥛", "cat": "乳製品"},
    {"name": "食パン", "unit": "枚", "limit": 5, "icon": "🍞", "cat": "主食"},
  ];

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな！"},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 自動補完（アイコンやカテゴリーも補完）
  void _autoFill(String name) {
    final all = [...userMaster, ...defaultMaster];
    try {
      final found = all.firstWhere((e) => e["name"] == name);
      setState(() {
        _unitController.text = found["unit"];
        _limitController.text = found["limit"].toString();
        _selectedCategory = found["cat"] ?? "その他";
      });
    } catch (_) {}
  }

  // アイコンを判定する
  String _getIcon(String name, String cat) {
    final all = [...userMaster, ...defaultMaster];
    try {
      return all.firstWhere((e) => e["name"] == name)["icon"];
    } catch (_) {
      if (cat == "肉類") return "🥩";
      if (cat == "野菜") return "🥬";
      if (cat == "主食") return "🍚";
      if (cat == "乳製品") return "🧀";
      return "📦";
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      userMaster = jsonDecode(prefs.getString('userMaster') ?? "[]");
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('userMaster', jsonEncode(userMaster));
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setInt('savedColor', customColor.value);
  }

  void _addFood() {
    String name = _nameController.text;
    if (name.isEmpty) return;
    
    String icon = _getIcon(name, _selectedCategory);
    double step = (name.contains("米") || _unitController.text == "kg") ? 0.15 : 1.0;
    final expiryDate = DateTime.now().add(Duration(days: int.tryParse(_limitController.text) ?? 3));

    setState(() {
      inventory.add({
        "name": name, "icon": icon, "expiry": expiryDate.toIso8601String(),
        "count": _inputCount, "unit": _unitController.text, "step": step,
      });
      if (![...userMaster, ...defaultMaster].any((e) => e["name"] == name)) {
        userMaster.add({
          "name": name, "unit": _unitController.text, 
          "limit": int.tryParse(_limitController.text) ?? 3, 
          "icon": icon, "cat": _selectedCategory
        });
      }
    });
    _speak("${charSettings[modeIndex]["msg"]} $nameを入れたぞ。");
    _nameController.clear();
    _inputCount = 1.0;
    _saveData();
    setState(() => _currentTabIndex = 0);
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
        backgroundColor: Colors.black26,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.palette), onPressed: _showSettingsDialog)],
      ),
      body: SafeArea(
        child: _currentTabIndex == 0 ? _buildInventoryView(textColor) :
              _currentTabIndex == 1 ? _buildAddView(textColor) : _buildHistoryView(textColor),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_shopping_cart), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "履歴"),
        ],
      ),
    );
  }

  // --- 在庫一覧 (アイコン付き) ---
  Widget _buildInventoryView(Color textColor) {
    return inventory.isEmpty
        ? Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)))
        : ListView.builder(
            itemCount: inventory.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final item = inventory[i];
              final double count = (item["count"] ?? 0).toDouble();
              final double step = (item["step"] ?? 1.0).toDouble();
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

  // --- 登録画面 (カテゴリー選択付き) ---
  Widget _buildAddView(Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Autocomplete<String>(
          optionsBuilder: (v) => [...userMaster, ...defaultMaster].map((e) => e["name"] as String).where((s) => s.contains(v.text)),
          onSelected: (name) { _nameController.text = name; _autoFill(name); },
          fieldViewBuilder: (ctx, ctrl, focus, onSubmitted) {
            ctrl.addListener(() => _nameController.text = ctrl.text);
            return TextField(
              controller: ctrl, focusNode: focus, onChanged: _autoFill,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: "食材名を入力...", labelStyle: TextStyle(color: textColor), filled: true, fillColor: Colors.black12, prefixIcon: const Icon(Icons.search)),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildDropdown("カテゴリー", ["肉類", "野菜", "主食", "乳製品", "その他"], _selectedCategory, (v) => setState(() => _selectedCategory = v!))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _unitController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "単位", labelStyle: TextStyle(color: textColor)))),
        ]),
        const SizedBox(height: 20),
        TextField(controller: _limitController, keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "賞味期限 (日)", labelStyle: TextStyle(color: textColor))),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: Icon(Icons.remove_circle_outline, color: textColor, size: 40), onPressed: () => setState(() { if(_inputCount > 1) _inputCount--; })),
          const SizedBox(width: 20),
          Text("${_inputCount.toInt()}", style: TextStyle(color: textColor, fontSize: 45, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          IconButton(icon: Icon(Icons.add_circle_outline, color: textColor, size: 40), onPressed: () => setState(() => _inputCount++)),
        ]),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 65), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          onPressed: _addFood,
          child: const Text("冷蔵庫に保管する", style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // --- 履歴画面 (カテゴリーごとに表示) ---
  Widget _buildHistoryView(Color textColor) {
    final list = [...userMaster, ...defaultMaster];
    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) => Card(
        color: Colors.white10,
        child: ListTile(
          leading: Text(list[i]["icon"] ?? "📦", style: const TextStyle(fontSize: 24)),
          title: Text(list[i]["name"], style: TextStyle(color: textColor)),
          subtitle: Text("${list[i]["cat"]} / ${list[i]["unit"]}", style: TextStyle(color: textColor.withOpacity(0.5))),
          trailing: const Icon(Icons.add_box, color: Colors.yellowAccent),
          onTap: () { setState(() { _nameController.text = list[i]["name"]; _unitController.text = list[i]["unit"]; _limitController.text = list[i]["limit"].toString(); _selectedCategory = list[i]["cat"] ?? "その他"; _currentTabIndex = 1; }); },
        ),
      ),
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
        TextButton.icon(icon: const Icon(Icons.colorize, color: Colors.yellowAccent), label: const Text("背景色を変える", style: TextStyle(color: Colors.yellowAccent)), 
          onPressed: () async { Navigator.pop(ctx); final result = await js.context.callMethod('eval', ["""new Promise((resolve) => { const input = document.createElement('input'); input.type = 'color'; input.onchange = () => resolve(input.value); input.click(); });"""]); if (result != null) { String hex = result.toString().replaceFirst('#', ''); setState(() { customColor = Color(int.parse("FF$hex", radix: 16)); }); _saveData(); } }),
      ]),
    ));
  }
}