// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; // 提供いただいた全食材データを参照

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

  // 登録用ステート
  String _selectedCategory = "肉類";
  String _selectedFoodName = "鶏むね肉";
  String _selectedUnit = "個";
  int _limitDays = 2;
  double _inputCount = 1.0;

  final List<String> unitOptions = ["個", "g", "kg", "ml", "本", "枚", "パック", "合"];

  // 背景色クイック選択用12色
  final List<Color> quickColors = [
    Colors.red[900]!, Colors.pink[900]!, Colors.purple[900]!, Colors.indigo[900]!,
    Colors.blue[900]!, Colors.cyan[900]!, Colors.teal[900]!, Colors.green[900]!,
    Colors.orange[900]!, Colors.brown[900]!, Colors.blueGrey[900]!, Colors.black,
  ];

  // NPCの詳細設定（一番最初のコードの雰囲気と台詞を完全復刻）
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

  // food_data.dart から期限の初期値を取得
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
    // 特殊計算：お米やkg単位は1合(0.15)ずつ
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
    // 背景の明るさに応じて文字色を決定
    Color textColor = customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["icon"]} ${charSettings[modeIndex]["name"]}の冷蔵庫", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.black38,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.palette, color: textColor),
            onPressed: _showSettingsDialog,
            tooltip: "設定",
          )
        ],
      ),
      body: _buildMainBody(textColor),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (i) => setState(() => _currentTabIndex = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: "探す"),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ"),
        ],
      ),
    );
  }

  Widget _buildMainBody(Color textColor) {
    switch (_currentTabIndex) {
      case 0: return _buildInventoryView(textColor);
      case 1: return _buildAddView(textColor);
      case 2: return _buildRecipeView(textColor);
      default: return _buildInventoryView(textColor);
    }
  }

  // --- タブ1: 在庫一覧 ---
  Widget _buildInventoryView(Color textColor) {
    if (inventory.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(charSettings[modeIndex]["icon"], style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Text(charSettings[modeIndex]["intro"], 
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 16, fontStyle: FontStyle.italic)),
        ]),
      );
    }
    return ListView.builder(
      itemCount: inventory.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        final item = inventory[i];
        final count = (item["count"] ?? 0).toDouble();
        final step = (item["step"] ?? 1.0).toDouble();
        final expiry = DateTime.parse(item["expiry"]);
        final days = expiry.difference(DateTime.now()).inDays;
        String displayCount = (count == count.toInt()) ? count.toInt().toString() : count.toStringAsFixed(2);
        String unit = item["unit"] ?? "個";

        return Card(
          color: days < 0 ? Colors.redAccent.withOpacity(0.4) : Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 35)),
            title: Text("${item["name"]} × $displayCount $unit", 
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(days < 0 ? "⚠️ 期限切れ！" : "あと $days 日で消費するんじゃぞ", 
              style: TextStyle(color: textColor.withOpacity(0.8))),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.orangeAccent, size: 30),
              onPressed: () {
                setState(() {
                  if (count > step + 0.001) {
                    inventory[i]["count"] = count - step;
                  } else {
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

  // --- タブ2: 登録（2段プルダウン） ---
  Widget _buildAddView(Color textColor) {
    List<String> foodOptions = (foodMaster[_selectedCategory] ?? []).map((e) => e["name"] as String).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLabel("1. カテゴリーを選択", textColor),
        _buildDropdown(foodMaster.keys.toList(), _selectedCategory, (v) {
          setState(() {
            _selectedCategory = v!;
            _selectedFoodName = foodMaster[v]![0]["name"];
            _updateFieldsFromMaster(_selectedFoodName);
          });
        }),
        const SizedBox(height: 25),
        _buildLabel("2. 食材を選択", textColor),
        _buildDropdown(foodOptions, _selectedFoodName, (v) {
          setState(() { _selectedFoodName = v!; _updateFieldsFromMaster(v); });
        }),
        const SizedBox(height: 25),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildLabel("3. 単位", textColor),
            _buildDropdown(unitOptions, _selectedUnit, (v) => setState(() => _selectedUnit = v!)),
          ])),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildLabel("4. 期限(日)", textColor),
            TextField(
              controller: TextEditingController(text: _limitDays.toString()),
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              onChanged: (v) => _limitDays = int.tryParse(v) ?? 3,
              decoration: InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ])),
        ]),
        const SizedBox(height: 40),
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _countBtn(Icons.remove, () => setState(() { if(_inputCount > 1) _inputCount--; })),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text("${_inputCount.toInt()}", style: TextStyle(color: textColor, fontSize: 55, fontWeight: FontWeight.bold)),
          ),
          _countBtn(Icons.add, () => setState(() => _inputCount++)),
        ])),
        const SizedBox(height: 50),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 65),
            backgroundColor: Colors.yellowAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
            elevation: 8,
          ),
          onPressed: _addFood,
          child: const Text("冷蔵庫に保管する", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // --- タブ3: レシピ ---
  Widget _buildRecipeView(Color textColor) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.menu_book, color: textColor.withOpacity(0.5), size: 100),
        const SizedBox(height: 20),
        Text("レシピ機能は開発中じゃ...", style: TextStyle(color: textColor, fontSize: 20)),
      ]),
    );
  }

  // --- 共通パーツ ---
  Widget _buildLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
  );

  Widget _buildDropdown(List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
      child: DropdownButton<String>(
        value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged, isExpanded: true, underline: const SizedBox(),
        dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _countBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.yellowAccent, size: 35),
    ),
  );

  // --- 設定ダイアログ ---
  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("アプリ設定", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("👤 キャラクター選択", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          ...List.generate(3, (i) => RadioListTile(
            title: Text("${charSettings[i]["icon"]} ${charSettings[i]["name"]}", style: const TextStyle(color: Colors.white)),
            value: i, groupValue: modeIndex, 
            onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); },
          )),
          const Divider(color: Colors.white24, height: 30),
          const Text("🎨 背景色 (12色から選ぶ)", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 15),
          Wrap(spacing: 12, runSpacing: 12, children: quickColors.map((color) => InkWell(
            onTap: () { setState(() => customColor = color); _saveData(); Navigator.pop(ctx); },
            child: Container(
              width: 45, height: 45, 
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 2)),
            ),
          )).toList()),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, minimumSize: const Size(double.infinity, 45)),
            icon: const Icon(Icons.colorize, color: Colors.cyanAccent),
            label: const Text("自由な色を選ぶ", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await js.context.callMethod('eval', ["""new Promise((resolve) => { const input = document.createElement('input'); input.type = 'color'; input.onchange = () => resolve(input.value); input.click(); });"""]);
              if (result != null) {
                String hex = result.toString().replaceFirst('#', '');
                setState(() { customColor = Color(int.parse("FF$hex", radix: 16)); });
                _saveData();
              }
            },
          ),
        ]),
      ),
    ));
  }
}