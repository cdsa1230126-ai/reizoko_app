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
  List<dynamic> userMaster = []; // ユーザーが登録した食材マスタ
  Color customColor = const Color(0xFF1B5E20);
  
  // 入力用コントローラー
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: "個");
  final TextEditingController _limitController = TextEditingController(text: "3");
  double _inputCount = 1.0;

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い食材だ。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな！"},
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

  void _speak(String text) {
    js.context.callMethod('eval', ["""
      window.speechSynthesis.cancel();
      const uttr = new SpeechSynthesisUtterance('$text');
      uttr.lang = 'ja-JP';
      window.speechSynthesis.speak(uttr);
    """]);
  }

  void _addFood(String name, String unit, int limit, double count) {
    if (name.isEmpty) return;
    // お米またはkg単位なら0.15(1合)をステップにする
    double step = (name == "お米" || unit == "kg") ? 0.15 : 1.0;
    final expiryDate = DateTime.now().add(Duration(days: limit));

    setState(() {
      inventory.add({
        "name": name,
        "icon": "📦",
        "expiry": expiryDate.toIso8601String(),
        "count": count,
        "unit": unit,
        "step": step,
      });
      if (!userMaster.any((e) => e["name"] == name)) {
        userMaster.add({"name": name, "unit": unit, "limit": limit});
      }
    });
    _speak("${charSettings[modeIndex]["msg"]} $nameを登録したぞ。");
    _nameController.clear();
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    // 明るさに応じて文字色を自動変更
    Color textColor = customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.palette), onPressed: _showSettingsDialog)],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildInventoryView(textColor),
          _buildAddView(textColor),
          _buildMasterView(textColor),
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
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "リスト"),
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
              final count = (item["count"] ?? 0).toDouble();
              final step = (item["step"] ?? 1.0).toDouble();
              final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
              
              String displayCount = (count == count.toInt()) ? count.toInt().toString() : count.toStringAsFixed(2);
              String minusLabel = (item["name"] == "お米" || item["unit"] == "kg") ? "1合使う" : "1${item["unit"]}使う";

              return Card(
                color: days < 0 ? Colors.red.withOpacity(0.4) : Colors.black26,
                child: ListTile(
                  title: Text("${item["name"]} × $displayCount ${item["unit"]}", 
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  subtitle: Text(days < 0 ? "期限切れ！" : "あと $days 日", 
                    style: TextStyle(color: textColor.withOpacity(0.7))),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent),
                        onPressed: () {
                          setState(() {
                            if (count > step + 0.001) {
                              inventory[i]["count"] = count - step;
                            } else {
                              _speak("${item["name"]}がなくなったぞ。");
                              inventory.removeAt(i);
                            }
                          });
                          _saveData();
                        },
                      ),
                      Text(minusLabel, style: TextStyle(color: textColor, fontSize: 9)),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // --- 登録画面 ---
  Widget _buildAddView(Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(labelText: "食材名", labelStyle: TextStyle(color: textColor), 
              filled: true, fillColor: Colors.black12, border: const OutlineInputBorder()),
            onChanged: (v) {
              // お米と入力されたら単位をkgに自動提案
              if(v == "お米") setState(() => _unitController.text = "kg");
            },
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: TextField(controller: _unitController, style: TextStyle(color: textColor), 
                decoration: InputDecoration(labelText: "単位", labelStyle: TextStyle(color: textColor)))),
              const SizedBox(width: 15),
              Expanded(child: TextField(controller: _limitController, keyboardType: TextInputType.number, 
                style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "期限(日)", labelStyle: TextStyle(color: textColor)))),
            ],
          ),
          const SizedBox(height: 25),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("数量: ", style: TextStyle(color: textColor, fontSize: 18)),
            IconButton(icon: Icon(Icons.remove_circle, color: textColor), onPressed: () => setState(() { if(_inputCount > 1) _inputCount--; })),
            Text("${_inputCount.toInt()}", style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
            IconButton(icon: Icon(Icons.add_circle, color: textColor), onPressed: () => setState(() => _inputCount++)),
          ]),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.yellowAccent),
            onPressed: () {
              _addFood(_nameController.text, _unitController.text, int.tryParse(_limitController.text) ?? 3, _inputCount);
              setState(() => _currentTabIndex = 0);
            },
            child: const Text("登録する", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- 学習済みリスト ---
  Widget _buildMasterView(Color textColor) {
    return userMaster.isEmpty
        ? Center(child: Text("まだリストが空じゃ。", style: TextStyle(color: textColor)))
        : ListView.builder(
            itemCount: userMaster.length,
            itemBuilder: (context, i) {
              final m = userMaster[i];
              return ListTile(
                title: Text(m["name"], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text("単位: ${m["unit"]} / 期限: ${m["limit"]}日", style: TextStyle(color: textColor.withOpacity(0.6))),
                trailing: const Icon(Icons.send, color: Colors.yellowAccent),
                onTap: () {
                  setState(() {
                    _nameController.text = m["name"];
                    _unitController.text = m["unit"];
                    _limitController.text = m["limit"].toString();
                    _currentTabIndex = 1;
                  });
                },
              );
            },
          );
  }

  // --- 設定ダイアログ ---
  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("アプリの設定"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("キャラクター"),
          ...List.generate(3, (i) => RadioListTile(
            title: Text(charSettings[i]["name"]), value: i, groupValue: modeIndex,
            onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); },
          )),
          const Divider(),
          ElevatedButton.icon(
            icon: const Icon(Icons.colorize),
            label: const Text("1600万色から背景を選ぶ"),
            onPressed: () async {
              Navigator.pop(ctx);
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
        ],
      ),
    ));
  }
}