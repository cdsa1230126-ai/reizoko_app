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

  String selectedIcon = "🥩";
  final List<String> icons = ["🥩", "🐟", "🥦", "🍎", "🥛", "🍚", "📦"];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(text: "3");
  final TextEditingController _countController = TextEditingController(text: "1");
  String _selectedUnit = "個";
  final List<String> _unitOptions = ["個", "kg", "g", "本", "ml", "L", "パック", "袋", "匹",];

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

  void _updateItemCount(int index, double newCount) {
    setState(() {
      if (newCount <= 0) {
        var item = inventory[index];
        recentlyConsumed.removeWhere((e) => e["name"] == item["name"]);
        recentlyConsumed.insert(0, item);
        if (autoShoppingAdd && !shoppingList.any((s) => s["name"] == item["name"])) {
          shoppingList.add(item);
        }
        _speak("${item["name"]}を使い切ったぞ！");
        inventory.removeAt(index);
      } else {
        inventory[index]["count"] = newCount;
      }
    });
    _saveData();
  }

  String _getNoticeMessage() {
    int urgentCount = inventory.where((item) {
      int days = int.tryParse(RegExp(r'\d+').stringMatch(item["limit"].toString()) ?? "999") ?? 999;
      return days <= 1;
    }).length;
    if (inventory.isEmpty) return "庫内は空っぽじゃ。新しい獲物を登録するのじゃ！";
    if (urgentCount > 0) return "⚠️ 警告：期限が近い魔物が $urgentCount 体おるぞ！早めに処理するのじゃ。";
    return "今日は平和じゃ。在庫は ${inventory.length} 種類、順調じゃな。";
  }

  // --- UI: 冷蔵庫リスト ---
  Widget _buildInventoryView(Color textColor) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.yellowAccent.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.campaign, color: Colors.yellowAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(_getNoticeMessage(), style: TextStyle(color: textColor, fontSize: 13))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: inventory.length,
          itemBuilder: (context, index) {
            final item = inventory[index];
            int days = int.tryParse(RegExp(r'\d+').stringMatch(item["limit"].toString()) ?? "999") ?? 999;
            bool isUrgent = days <= 1;
            double currentVal = double.tryParse(item["count"].toString()) ?? 1.0;

            return Card(
              color: isUrgent ? Colors.redAccent.withOpacity(0.5 + (_blinkController.value * 0.3)) : Colors.black26,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: ListTile(
                leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
                title: Text(item["name"], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Row(children: [
                  Text("あと ", style: TextStyle(color: textColor.withOpacity(0.7))),
                  DropdownButton<double>(
                    value: currentVal > 50 ? 50 : currentVal,
                    dropdownColor: Colors.grey[900],
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.yellowAccent, size: 18),
                    style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold),
                    items: List.generate(51, (i) => i.toDouble()).map((val) => 
                      DropdownMenuItem(value: val, child: Text("${val.toInt()}"))
                    ).toList(),
                    onChanged: (v) => _updateItemCount(index, v!),
                  ),
                  Text(" ${item["unit"] ?? '個'}", style: TextStyle(color: textColor.withOpacity(0.7))),
                ]),
                trailing: Text(item["limit"], style: TextStyle(color: isUrgent ? Colors.white : Colors.greenAccent, fontWeight: FontWeight.bold)),
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
      Text("🎨 アイコン選択", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, children: icons.map((icon) => GestureDetector(onTap: () => setState(() => selectedIcon = icon), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: selectedIcon == icon ? Colors.yellowAccent : Colors.white12, borderRadius: BorderRadius.circular(8)), child: Text(icon, style: const TextStyle(fontSize: 24))))).toList()),
      const SizedBox(height: 20),
      TextField(controller: _nameController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "食材名（魔物名）", labelStyle: TextStyle(color: textColor.withOpacity(0.6)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: textColor.withOpacity(0.3))))),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: TextField(controller: _countController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "初期数", labelStyle: TextStyle(color: textColor.withOpacity(0.6))))),
        const SizedBox(width: 10),
        DropdownButton<String>(value: _selectedUnit, dropdownColor: Colors.black87, style: TextStyle(color: textColor), items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _selectedUnit = v!)),
      ]),
      const SizedBox(height: 15),
      TextField(controller: _dateController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "消費期限（あと何日？）", labelStyle: TextStyle(color: textColor.withOpacity(0.6)))),
      const SizedBox(height: 40),
      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () {
        if (_nameController.text.isNotEmpty) {
          setState(() {
            inventory.add({
              "name": _nameController.text, "icon": selectedIcon, "limit": "あと${_dateController.text}日", "count": double.tryParse(_countController.text) ?? 1.0, "unit": _selectedUnit
            });
          });
          _nameController.clear(); _saveData(); setState(() => _currentTabIndex = 0);
        }
      }, child: const Text("冒険の書に登録！", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))))
    ]));
  }

  void _showShoppingList() {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("🛒 買い物リスト", style: TextStyle(color: Colors.white)),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (shoppingList.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("リストは空です", style: TextStyle(color: Colors.white54))),
          ...shoppingList.asMap().entries.map((e) => ListTile(
            leading: Text(e.value["icon"] ?? "📦"),
            title: Text(e.value["name"], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(icon: const Icon(Icons.check_box, color: Colors.green), onPressed: () {
              setState(() => shoppingList.removeAt(e.key)); _saveData(); setDialogState(() {});
            }),
          )),
          const Divider(color: Colors.white24, thickness: 1),
          const Text("🍴 最近使い切ったもの (履歴)", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ...recentlyConsumed.map((item) => ListTile(
            leading: Text(item["icon"] ?? "📦"),
            title: Text(item["name"], style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.add_shopping_cart, color: Colors.yellowAccent),
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
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("システム設定"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          title: const Text("自動買い物登録"),
          subtitle: const Text("0個になると自動で買い物リストへ"),
          value: autoShoppingAdd,
          onChanged: (v) { setState(() => autoShoppingAdd = v); _saveData(); Navigator.pop(context); },
        ),
        const Divider(),
        ...List.generate(3, (i) => RadioListTile(value: i, groupValue: modeIndex, title: Text(charSettings[i]["name"]), onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(context); })),
      ]),
    ));
  }

  final List<Map<String, dynamic>> charSettings = [{"name": "🧓 長老"}, {"name": "🧑‍⚕️ 博士"}, {"name": "🕶️ 商人"}];
  void _speak(String text) { js.context.callMethod('eval', ["""window.speechSynthesis.cancel(); const uttr = new SpeechSynthesisUtterance('$text'); uttr.lang = 'ja-JP'; window.speechSynthesis.speak(uttr);"""]); }

  @override
  Widget build(BuildContext context) {
    Color textColor = Colors.white;
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26,
        actions: [
          IconButton(onPressed: _showShoppingList, icon: const Icon(Icons.shopping_cart, color: Colors.white)),
          IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings, color: Colors.white)),
        ],
      ),
      body: IndexedStack(index: _currentTabIndex, children: [
        _buildInventoryView(textColor),
        _buildAddView(textColor),
        const Center(child: Text("図鑑・レシピ機能は準備中...", style: TextStyle(color: Colors.white54))),
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