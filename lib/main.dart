// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js; // Web用。モバイル化する場合は flutter_tts 等に変更検討

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

class _ReizokoAppState extends State<ReizokoApp> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  int modeIndex = 0; 
  List<dynamic> inventory = [];
  Color customColor = const Color(0xFF1B5E20);
  String recipeApiKey = "";

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。大事にするのじゃぞ。", "search": "のレシピを探してきたぞ。心して作るのじゃ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い食材だ。効率よく調理したまえ。", "search": "の最適な調理法を検索した。データを確認してくれ。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな。高く売れそうですぞ！", "search": "のレシピを見つけました！これで一儲けですな。"},
  ];

  final Map<String, List<Map<String, dynamic>>> _foodMaster = {
    "鶏肉": [
      {"name": "鶏むね肉", "icon": "🍗", "limit": 2},
      {"name": "鶏もも肉", "icon": "🍗", "limit": 2},
      {"name": "ささみ", "icon": "🍗", "limit": 2},
      {"name": "手羽先", "icon": "🍗", "limit": 2},
      {"name": "鶏ひき肉", "icon": "🥩", "limit": 1},
    ],
    "豚肉": [
      {"name": "豚バラ肉", "icon": "🥩", "limit": 3},
      {"name": "豚ロース", "icon": "🥩", "limit": 3},
      {"name": "豚こま切れ", "icon": "🥩", "limit": 3},
      {"name": "豚ひき肉", "icon": "🥩", "limit": 2},
    ],
    "牛肉": [
      {"name": "牛サーロイン", "icon": "🥩", "limit": 3},
      {"name": "牛もも肉", "icon": "🥩", "limit": 3},
      {"name": "牛バラ肉", "icon": "🥩", "limit": 3},
      {"name": "牛ひき肉", "icon": "🥩", "limit": 2},
    ],
    "世界・加工品": [
      {"name": "サーモン", "icon": "🐟", "limit": 2},
      {"name": "アボカド", "icon": "🥑", "limit": 5},
      {"name": "生ハム", "icon": "🥓", "limit": 10},
      {"name": "モッツァレラ", "icon": "🧀", "limit": 7},
      {"name": "キムチ", "icon": "🌶️", "limit": 14},
    ],
  };

  String _selectedCategory = "鶏肉";
  String _selectedFoodName = "鶏むね肉";
  final TextEditingController _customFoodController = TextEditingController();

  Color get _dynamicTextColor =>
      customColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _speak(String text) {
    js.context.callMethod('eval', ["""
      window.speechSynthesis.cancel();
      const uttr = new SpeechSynthesisUtterance('$text');
      uttr.lang = 'ja-JP';
      window.speechSynthesis.speak(uttr);
    """]);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      recipeApiKey = prefs.getString('recipeApiKey') ?? "";
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      int? savedColor = prefs.getInt('savedColor');
      if (savedColor != null) customColor = Color(savedColor);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('recipeApiKey', recipeApiKey);
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setInt('savedColor', customColor.value);
  }

  // --- 追加：期限までの残り日数を計算する関数 ---
  int _calculateDaysLeft(String expiryDateStr) {
    final expiry = DateTime.parse(expiryDateStr);
    final now = DateTime.now();
    return expiry.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${charSettings[modeIndex]["name"]}の冷蔵庫", 
          style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black26,
        elevation: 0,
        iconTheme: IconThemeData(color: _dynamicTextColor),
        actions: [
          IconButton(icon: Icon(Icons.settings, color: _dynamicTextColor), onPressed: _showSettingsDialog),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildInventoryView(),
          _buildAddView(),
          _buildRecipeSettingView(),
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
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AI設定"),
        ],
      ),
    );
  }

  // --- 1. 在庫一覧（残り日数を表示するように変更） ---
  Widget _buildInventoryView() {
    return ListView.builder(
      itemCount: inventory.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final item = inventory[index];
        final daysLeft = _calculateDaysLeft(item["expiry"]);
        final isExpired = daysLeft < 0;

        return Card(
          color: isExpired ? Colors.red.withOpacity(0.3) : Colors.black38,
          child: ListTile(
            leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 26)),
            title: Text(item["name"], style: TextStyle(color: _dynamicTextColor)),
            subtitle: Text(
              isExpired ? "期限切れ！" : "あと $daysLeft 日",
              style: TextStyle(color: isExpired ? Colors.redAccent : _dynamicTextColor.withOpacity(0.7)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
              onPressed: () {
                _speak("${item["name"]}を使い切りましたな！お見事です！");
                setState(() { inventory.removeAt(index); _saveData(); });
              },
            ),
          ),
        );
      },
    );
  }

  // --- 2. 登録（マスターデータの反映と日付計算を追加） ---
  Widget _buildAddView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("カテゴリ選択", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            dropdownColor: Colors.grey[900],
            style: TextStyle(color: _dynamicTextColor),
            items: _foodMaster.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedCategory = v!;
                _selectedFoodName = _foodMaster[v]![0]["name"];
              });
            },
          ),
          const SizedBox(height: 20),
          Text("食材を選択", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _selectedFoodName,
            isExpanded: true,
            dropdownColor: Colors.grey[900],
            style: TextStyle(color: _dynamicTextColor),
            items: _foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(value: f["name"] as String, child: Text("${f["icon"]} ${f["name"]}"))).toList(),
            onChanged: (v) => setState(() => _selectedFoodName = v!),
          ),
          const SizedBox(height: 20),
          Text("自由入力（名前を変えたい場合）", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
          TextField(
            controller: _customFoodController,
            style: TextStyle(color: _dynamicTextColor),
            decoration: InputDecoration(
              hintText: "例: 特売の鶏肉",
              hintStyle: TextStyle(color: _dynamicTextColor.withOpacity(0.4)),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, minimumSize: const Size(double.infinity, 50)),
            onPressed: () {
              final name = _customFoodController.text.isNotEmpty ? _customFoodController.text : _selectedFoodName;
              
              // マスターからアイコンと期限(limit)を取得
              final masterItem = _foodMaster[_selectedCategory]!.firstWhere((e) => e["name"] == _selectedFoodName);
              final icon = masterItem["icon"];
              final int limitDays = masterItem["limit"];
              
              // 現在の日付にlimitを足して保存
              final expiryDate = DateTime.now().add(Duration(days: limitDays));

              _speak(charSettings[modeIndex]["msg"]);
              
              setState(() {
                inventory.add({
                  "name": name,
                  "icon": icon,
                  "expiry": expiryDate.toIso8601String(),
                });
              });

              _customFoodController.clear();
              _saveData();
              setState(() => _currentTabIndex = 0);
            },
            child: const Text("冷蔵庫に入れる", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- 3. API設定（変更なし） ---
  Widget _buildRecipeSettingView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.vpn_key, size: 50, color: _dynamicTextColor),
          const SizedBox(height: 20),
          Text("AI提案の鍵 (APIキー)", style: TextStyle(color: _dynamicTextColor, fontSize: 18)),
          const SizedBox(height: 10),
          TextField(
            obscureText: true,
            style: TextStyle(color: _dynamicTextColor),
            decoration: InputDecoration(enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _dynamicTextColor))),
            onChanged: (v) { recipeApiKey = v; _saveData(); },
          ),
          TextButton(onPressed: () => js.context.callMethod('open', ['https://platform.openai.com/api-keys']), child: const Text("キーの取得はこちら")),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("アプリ設定"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("キャラクター選択"),
          ...List.generate(3, (i) => RadioListTile(
            title: Text(charSettings[i]["name"]),
            value: i,
            groupValue: modeIndex,
            onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(ctx); },
          )),
          const Divider(),
          ElevatedButton(onPressed: _showColorPicker, child: const Text("背景色を変える")),
        ],
      ),
    ));
  }

  void _showColorPicker() {
    Navigator.pop(context);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("色選択"),
      content: Wrap(
        children: [Colors.red, Colors.blue, Colors.green, Colors.black, Colors.orange, Colors.purple].map((c) => GestureDetector(
          onTap: () { setState(() => customColor = c); _saveData(); Navigator.pop(ctx); },
          child: Container(width: 50, height: 50, color: c, margin: const EdgeInsets.all(4)),
        )).toList(),
      ),
    ));
  }
}