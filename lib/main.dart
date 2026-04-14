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
  List<dynamic> shoppingList = [];
  Color customColor = const Color(0xFF1B5E20);

  // --- 登録用ステート ---
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  String _selectedUnit = "個";
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3)); 
  double _inputCount = 1.0;
  bool _isFavorite = false; 

  double _volumeValue = 500.0;
  String _volumeUnit = "ml";

  final List<String> unitOptions = ["個", "g", "kg", "ml", "本", "枚", "パック", "合"];
  final List<String> volUnitOptions = ["ml", "L"];
  final List<String> countOptions = List.generate(20, (i) => (i + 1).toString());

  final List<Color> expandedColors = [
    Colors.black, const Color(0xFF263238), const Color(0xFF3E2723), const Color(0xFF1A237E),
    const Color(0xFF004D40), const Color(0xFF311B92), const Color(0xFF1B5E20), const Color(0xFF0D47A1),
    const Color(0xFF827717), const Color(0xFFBF360C), const Color(0xFF4E342E), const Color(0xFF424242),
    const Color(0xFFFFCDD2), const Color(0xFFF8BBD0), const Color(0xFFE1BEE7), const Color(0xFFD1C4E9),
    const Color(0xFFC5CAE9), const Color(0xFFB3E5FC), const Color(0xFFB2DFDB), const Color(0xFFDCEDC8),
    const Color(0xFFFFF9C4), const Color(0xFFFFECB3), const Color(0xFFFFE0B2), const Color(0xFFFFCCBC),
  ];

  final List<Map<String, dynamic>> charSettings = [
    {"name": "長老", "icon": "🧓", "intro": "フォッフォッフォ、ワシの冷蔵庫へようこそ。", "msg": "おぉ、それは良い食材じゃ。"},
    {"name": "博士", "icon": "🧑‍⚕️", "intro": "私のラボへ。鮮度はデータがすべてだ。", "msg": "フム、実に興味深い仕入れだ。"},
    {"name": "商人", "icon": "🕶️", "intro": "ヘイお待ち！ここは最高の仕入れ場だ。", "msg": "まいど！活きのいいのが入りましたな！"},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFieldsFromMaster("鶏むね肉");
  }

  // 日付のフォーマット関数（intlエラー回避用）
  String _formatDate(DateTime dt) {
    return "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
  }

  void _updateFieldsFromMaster(String foodName) {
    for (var cat in foodMaster.values) {
      for (var item in cat) {
        if (item["name"] == foodName) {
          setState(() { 
            _selectedDate = DateTime.now().add(Duration(days: item["limit"])); 
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
      shoppingList = jsonDecode(prefs.getString('shoppingList') ?? "[]");
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('shoppingList', jsonEncode(shoppingList));
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setInt('savedColor', customColor.value);
  }

  void _addFood() {
    double step = (_selectedFoodName.contains("米") || _selectedUnit == "kg" || _selectedUnit == "合") ? 0.15 : 1.0;
    
    setState(() {
      inventory.add({
        "name": _selectedFoodName,
        "icon": _getIcon(_selectedFoodName),
        "expiry": _selectedDate.toIso8601String(),
        "count": _inputCount,
        "unit": _selectedUnit,
        "step": step,
        "volume": _selectedCategory == "飲み物" ? _volumeValue : null,
        "volUnit": _selectedCategory == "飲み物" ? _volumeUnit : null,
        "isFavorite": _isFavorite,
      });
    });

    _speak("${charSettings[modeIndex]["msg"]} $_selectedFoodNameを入れたぞ。");
    _saveData();
    setState(() { _currentTabIndex = 0; _inputCount = 1.0; _isFavorite = false; });
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) { setState(() { _selectedDate = picked; }); }
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
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "登録"), 
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"), 
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ"),
        ],
      ),
    );
  }

  Widget _buildPageContent(Color textColor) {
    if (_currentTabIndex == 0) return _buildInventoryTab(textColor);
    if (_currentTabIndex == 1) return _buildAddTab(textColor);
    if (_currentTabIndex == 2) return _buildShoppingTab(textColor);
    return Center(child: Text("レシピ機能は開発中じゃ...", style: TextStyle(color: textColor, fontSize: 20)));
  }

  // --- 在庫タブ ---
  Widget _buildInventoryTab(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text(charSettings[modeIndex]["intro"], textAlign: TextAlign.center, style: TextStyle(color: textColor)));
    return ListView.builder(
      itemCount: inventory.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        final item = inventory[i];
        final count = (item["count"] ?? 0).toDouble();
        final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays + 1;
        bool isFav = item["isFavorite"] ?? false;
        String volInfo = (item["volume"] != null) ? " (${item["volume"].toInt()}${item["volUnit"]})" : "";

        return Card(
          color: days <= 0 ? Colors.redAccent.withOpacity(0.4) : Colors.black45,
          child: ListTile(
            leading: GestureDetector(
              onTap: () { setState(() { inventory[i]["isFavorite"] = !isFav; }); _saveData(); },
              child: Stack(alignment: Alignment.bottomRight, children: [
                Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 35)),
                Icon(isFav ? Icons.star : Icons.star_border, color: Colors.yellowAccent, size: 22),
              ]),
            ),
            title: Text("${item["name"]} × ${count.toStringAsFixed(count == count.toInt() ? 0 : 2)} ${item["unit"]}$volInfo", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text(days <= 0 ? "⚠️ 期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.8))),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.orangeAccent, size: 30),
              onPressed: () {
                setState(() {
                  double step = (item["step"] ?? 1.0).toDouble();
                  if (count > step + 0.001) {
                    inventory[i]["count"] = count - step;
                  } else {
                    shoppingList.add(Map.from(inventory[i]));
                    inventory.removeAt(i);
                  }
                });
                _saveData();
              },
            ),
          ),
        );
      },
    );
  }

  // --- 登録タブ ---
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
        const SizedBox(height: 20),
        _buildSectionLabel("2. 食材を選択", textColor),
        _buildStyledDropdown(foodOptions, _selectedFoodName, (v) { setState(() { _selectedFoodName = v!; _updateFieldsFromMaster(v); }); }),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSectionLabel("3. 単位", textColor),
            _buildStyledDropdown(unitOptions, _selectedUnit, (v) => setState(() => _selectedUnit = v!)),
          ])),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildSectionLabel("4. 賞味期限を選択", textColor),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                child: Row(children: [
                  Icon(Icons.calendar_today, color: textColor, size: 16),
                  const SizedBox(width: 8),
                  Text(_formatDate(_selectedDate), style: TextStyle(color: textColor)),
                ]),
              ),
            ),
          ])),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSectionLabel("5. 個数を選択", textColor),
          Row(children: [
            Text("★ お気に入り", style: TextStyle(color: textColor, fontSize: 13)),
            Switch(value: _isFavorite, activeColor: Colors.yellowAccent, onChanged: (v) => setState(() => _isFavorite = v)),
          ]),
        ]),
        Row(children: [
          Expanded(child: _buildStyledDropdown(countOptions, _inputCount.toInt().clamp(1, 20).toString(), (v) => setState(() => _inputCount = double.parse(v!)))),
          const SizedBox(width: 15),
          _buildCountIcon(Icons.remove, () => setState(() { if(_inputCount > 1) _inputCount--; })),
          const SizedBox(width: 5),
          _buildCountIcon(Icons.add, () => setState(() => _inputCount++)),
        ]),
        if (isDrink) ...[
          const SizedBox(height: 25),
          _buildSectionLabel("🥤 飲み物の容量設定", textColor),
          Row(children: [
            Expanded(flex: 2, child: TextField(keyboardType: TextInputType.number, style: TextStyle(color: textColor), onChanged: (v) => _volumeValue = double.tryParse(v) ?? 500, decoration: InputDecoration(hintText: "500", filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: _buildStyledDropdown(volUnitOptions, _volumeUnit, (v) => setState(() => _volumeUnit = v!))),
          ]),
        ],
        const SizedBox(height: 40),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _addFood, child: const Text("冷蔵庫に保管する", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  // --- 買い物タブ ---
  Widget _buildShoppingTab(Color textColor) {
    if (shoppingList.isEmpty) return Center(child: Text("買い物リストは空じゃ。", style: TextStyle(color: textColor)));
    shoppingList.sort((a, b) => ((a["isFavorite"] ?? false) ? 0 : 1).compareTo((b["isFavorite"] ?? false) ? 0 : 1));
    return ListView.builder(
      itemCount: shoppingList.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        final item = shoppingList[i];
        bool isFav = item["isFavorite"] ?? false;
        return Card(
          color: Colors.white10,
          child: ListTile(
            leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 30)),
            title: Text("${isFav ? '★ ' : ''}${item["name"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text("単位: ${item["unit"]}"),
            trailing: IconButton(icon: const Icon(Icons.add_shopping_cart, color: Colors.cyanAccent), onPressed: () {
              setState(() {
                item["expiry"] = DateTime.now().add(const Duration(days: 3)).toIso8601String();
                item["count"] = 1.0;
                inventory.add(Map.from(item));
                shoppingList.removeAt(i);
              });
              _saveData();
            }),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String text, Color color) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)));
  Widget _buildStyledDropdown(List<String> items, String value, ValueChanged<String?> onChanged) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)), child: DropdownButton<String>(value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged, isExpanded: true, underline: const SizedBox(), dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white)));
  Widget _buildCountIcon(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Icon(icon, color: Colors.yellowAccent, size: 24)));

  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("アプリ設定", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...List.generate(3, (i) => RadioListTile(title: Text("${charSettings[i]["icon"]} ${charSettings[i]["name"]}", style: const TextStyle(color: Colors.white)), value: i, groupValue: modeIndex, onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); })),
          const Divider(color: Colors.white24),
          Wrap(spacing: 8, runSpacing: 8, children: expandedColors.map((color) => InkWell(onTap: () { setState(() => customColor = color); _saveData(); Navigator.pop(ctx); }, child: Container(width: 35, height: 35, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white38))))).toList()),
          const SizedBox(height: 20),
          ElevatedButton.icon(icon: const Icon(Icons.colorize), label: const Text("自由な色を選ぶ"), onPressed: () async {
            final result = await js.context.callMethod('eval', ["""new Promise((resolve) => { const input = document.createElement('input'); input.type = 'color'; input.onchange = () => resolve(input.value); input.click(); });"""]);
            if (result != null) { setState(() { customColor = Color(int.parse("FF${result.toString().replaceFirst('#', '')}", radix: 16)); }); _saveData(); Navigator.pop(ctx); }
          }),
        ]),
      ),
    ));
  }
}