// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; // 送っていただいたマスターデータを参照

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

  // --- 登録用ステート（すべて保持） ---
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  String _selectedUnit = "個";
  int _limitDays = 2;
  double _inputCount = 1.0;

  // 飲み物用の詳細ステート
  double _volumeValue = 500.0;
  String _volumeUnit = "ml";

  final List<String> unitOptions = ["個", "g", "kg", "ml", "本", "枚", "パック", "合"];
  final List<String> volUnitOptions = ["ml", "L"];

  // --- 【強化】かわいい ＆ かっこいい 24色パレット ---
  final List<Color> expandedColors = [
    // かっこいい・ダーク系
    Colors.black, const Color(0xFF263238), const Color(0xFF3E2723), const Color(0xFF1A237E),
    const Color(0xFF004D40), const Color(0xFF311B92), const Color(0xFF1B5E20), const Color(0xFF0D47A1),
    const Color(0xFF827717), const Color(0xFFBF360C), const Color(0xFF4E342E), const Color(0xFF424242),
    // かわいい・パステル系（追加）
    const Color(0xFFFFCDD2), const Color(0xFFF8BBD0), const Color(0xFFE1BEE7), const Color(0xFFD1C4E9),
    const Color(0xFFC5CAE9), const Color(0xFFB3E5FC), const Color(0xFFB2DFDB), const Color(0xFFDCEDC8),
    const Color(0xFFFFF9C4), const Color(0xFFFFECB3), const Color(0xFFFFE0B2), const Color(0xFFFFCCBC),
  ];

  // NPCの台詞・設定（完全維持）
  final List<Map<String, dynamic>> charSettings = [
    {
      "name": "長老", 
      "icon": "🧓", 
      "intro": "フォッフォッフォ、ワシの冷蔵庫へようこそ。中身をしっかり管理するんじゃよ。",
      "msg": "おぉ、それは良い食材じゃ。大切に使うんじゃぞ。"
    },
    {
      "name": "博士", 
      "icon": "🧑‍⚕️", 
      "intro": "私のラボ（冷蔵庫）へ。食材の鮮度はデータがすべてだ。効率よく消費したまえ。",
      "msg": "フム、実に興味深い。栄養バランスも考慮された完璧な仕入れだ。"
    },
    {
      "name": "商人", 
      "icon": "🕶️", 
      "intro": "ヘイお待ち！ここは最高の仕入れ場だ。賞味期限ギリギリで売るんじゃねえぞ！",
      "msg": "まいど！こいつはまた活きのいいのが入りましたな！ガッポリ稼がせてもらうぜ！"
    },
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
          setState(() { _limitDays = item["limit"]; });
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
    // お米やkg、合の場合は0.15ずつ減らすロジックを維持
    double step = (_selectedFoodName.contains("米") || _selectedUnit == "kg" || _selectedUnit == "合") ? 0.15 : 1.0;
    final expiryDate = DateTime.now().add(Duration(days: _limitDays));

    setState(() {
      inventory.add({
        "name": _selectedFoodName,
        "icon": _getIcon(_selectedFoodName),
        "expiry": expiryDate.toIso8601String(),
        "count": _inputCount,
        "unit": _selectedUnit,
        "step": step,
        "volume": _selectedCategory == "飲み物" ? _volumeValue : null,
        "volUnit": _selectedCategory == "飲み物" ? _volumeUnit : null,
      });
    });

    _speak("${charSettings[modeIndex]["msg"]} $_selectedFoodNameを入れたぞ。");
    _saveData();
    setState(() { _currentTabIndex = 0; _inputCount = 1.0; });
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
        title: Text("${charSettings[modeIndex]["icon"]} ${charSettings[modeIndex]["name"]}の冷蔵庫", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black38,
        elevation: 4,
        actions: [IconButton(icon: Icon(Icons.palette, color: textColor), onPressed: _showSettingsDialog)],
      ),
      body: _buildPageContent(textColor),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "探す"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ"),
        ],
      ),
    );
  }

  Widget _buildPageContent(Color textColor) {
    if (_currentTabIndex == 0) return _buildInventoryTab(textColor);
    if (_currentTabIndex == 1) return _buildAddTab(textColor);
    return _buildRecipeTab(textColor);
  }

  // --- 在庫表示（飲み物容量の表示を維持） ---
  Widget _buildInventoryTab(Color textColor) {
    if (inventory.isEmpty) {
      return Center(child: Text(charSettings[modeIndex]["intro"], 
        textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 16)));
    }
    return ListView.builder(
      itemCount: inventory.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        final item = inventory[i];
        final count = (item["count"] ?? 0).toDouble();
        final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
        String displayCount = (count == count.toInt()) ? count.toInt().toString() : count.toStringAsFixed(2);
        String volInfo = (item["volume"] != null) ? " (${item["volume"].toInt()}${item["volUnit"]})" : "";

        return Card(
          color: days < 0 ? Colors.redAccent.withOpacity(0.4) : Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 35)),
            title: Text("${item["name"]} × $displayCount ${item["unit"]}$volInfo", 
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text(days < 0 ? "⚠️ 期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.8))),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.orangeAccent, size: 30),
              onPressed: () {
                setState(() {
                  double step = (item["step"] ?? 1.0).toDouble();
                  if (count > step + 0.001) { inventory[i]["count"] = count - step; } else { inventory.removeAt(i); }
                });
                _saveData();
              },
            ),
          ),
        );
      },
    );
  }

  // --- 登録（飲み物用入力UIを維持） ---
  Widget _buildAddTab(Color textColor) {
    List<String> foodOptions = (foodMaster[_selectedCategory] ?? []).map((e) => e["name"] as String).toList();
    bool isDrink = _selectedCategory == "飲み物";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabel("1. カテゴリーを選択", textColor),
        _buildStyledDropdown(foodMaster.keys.toList(), _selectedCategory, (v) {
          setState(() { _selectedCategory = v!; _selectedFoodName = foodMaster[v]![0]["name"]; _updateFieldsFromMaster(_selectedFoodName); });
        }),
        const SizedBox(height: 25),
        _buildSectionLabel("2. 食材を選択", textColor),
        _buildStyledDropdown(foodOptions, _selectedFoodName, (v) { setState(() { _selectedFoodName = v!; _updateFieldsFromMaster(v); }); }),
        const SizedBox(height: 25),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSectionLabel("3. 単位", textColor),
            _buildStyledDropdown(unitOptions, _selectedUnit, (v) => setState(() => _selectedUnit = v!)),
          ])),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSectionLabel("4. 期限(日)", textColor),
            TextField(
              controller: TextEditingController(text: _limitDays.toString()),
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              onChanged: (v) => _limitDays = int.tryParse(v) ?? 3,
              decoration: InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ])),
        ]),

        if (isDrink) ...[
          const SizedBox(height: 30),
          _buildSectionLabel("🥤 飲み物の容量設定", textColor),
          Row(children: [
            Expanded(flex: 2, child: TextField(
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              onChanged: (v) => _volumeValue = double.tryParse(v) ?? 500,
              decoration: InputDecoration(hintText: "例: 500", hintStyle: TextStyle(color: textColor.withOpacity(0.5)), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: _buildStyledDropdown(volUnitOptions, _volumeUnit, (v) => setState(() => _volumeUnit = v!))),
          ]),
        ],

        const SizedBox(height: 45),
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _buildCountIcon(Icons.remove, () => setState(() { if(_inputCount > 1) _inputCount--; })),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 35), child: Text("${_inputCount.toInt()}", style: TextStyle(color: textColor, fontSize: 55, fontWeight: FontWeight.bold))),
          _buildCountIcon(Icons.add, () => setState(() => _inputCount++)),
        ])),
        const SizedBox(height: 50),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 65), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)), elevation: 8),
          onPressed: _addFood,
          child: const Text("冷蔵庫に保管する", style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildRecipeTab(Color textColor) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.menu_book, size: 80, color: textColor.withOpacity(0.4)),
    const SizedBox(height: 20),
    Text("レシピ機能は開発中じゃ...", style: TextStyle(color: textColor, fontSize: 20)),
  ]));

  Widget _buildSectionLabel(String text, Color color) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 5), child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)));

  Widget _buildStyledDropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: DropdownButton<String>(
        value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged, isExpanded: true, underline: const SizedBox(),
        dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildCountIcon(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.yellowAccent, size: 38),
    ),
  );

  // --- 設定ダイアログ（24色 ＆ 自由色選択の修正） ---
  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: const Text("アプリ設定", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("👤 キャラクター切り替え", style: TextStyle(color: Colors.white70, fontSize: 13)),
          ...List.generate(3, (i) => RadioListTile(
            title: Text("${charSettings[i]["icon"]} ${charSettings[i]["name"]}", style: const TextStyle(color: Colors.white)),
            value: i, groupValue: modeIndex, 
            onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); },
          )),
          const Divider(color: Colors.white24, height: 30),
          const Text("🎨 背景色 (24色パレット)", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 15),
          Wrap(spacing: 10, runSpacing: 10, children: expandedColors.map((color) => InkWell(
            onTap: () { setState(() => customColor = color); _saveData(); Navigator.pop(ctx); },
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 2))),
          )).toList()),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, minimumSize: const Size(double.infinity, 45)),
            icon: const Icon(Icons.colorize, color: Colors.cyanAccent),
            label: const Text("自由な色を選ぶ", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final result = await js.context.callMethod('eval', ["""new Promise((resolve) => { const input = document.createElement('input'); input.type = 'color'; input.onchange = () => resolve(input.value); input.click(); });"""]);
              if (result != null) {
                setState(() { customColor = Color(int.parse("FF${result.toString().replaceFirst('#', '')}", radix: 16)); });
                _saveData();
                if (mounted) Navigator.pop(ctx); // 色選択後にダイアログを閉じる
              }
            },
          ),
        ]),
      ),
    ));
  }
}