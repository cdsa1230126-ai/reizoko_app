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

class _ReizokoAppState extends State<ReizokoApp> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  int modeIndex = 0; // 0:長老, 1:博士, 2:商人
  List<dynamic> inventory = [];
  Color customColor = const Color(0xFF1B5E20);
  String recipeApiKey = "";

  // --- NPCの設定 ---
  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "msg": "おぉ、それは良い食材じゃ。大事にするのじゃぞ。"},
    {"name": "🧑‍⚕️ 博士", "msg": "フム、実に興味深い食材だ。効率よく調理したまえ。"},
    {"name": "🕶️ 商人", "msg": "まいど！良い仕入れですな。高く売れそうですぞ！"},
  ];

  // --- 網羅された食材マスタ（2段階連動用） ---
  final Map<String, List<Map<String, dynamic>>> _foodMaster = {
    "肉類": [
      {"name": "鶏むね肉", "icon": "🍗", "limit": 2},
      {"name": "鶏もも肉", "icon": "🍗", "limit": 2},
      {"name": "豚バラ肉", "icon": "🥩", "limit": 3},
      {"name": "牛ステーキ肉", "icon": "🥩", "limit": 3},
      {"name": "ひき肉", "icon": "🥡", "limit": 1},
      {"name": "ハム・ソーセージ", "icon": "🥓", "limit": 7},
    ],
    "魚介類": [
      {"name": "鮭の切り身", "icon": "🐟", "limit": 3},
      {"name": "刺身", "icon": "🍣", "limit": 1},
      {"name": "えび・いか", "icon": "🦐", "limit": 2},
      {"name": "あじ・いわし", "icon": "🐟", "limit": 2},
    ],
    "野菜": [
      {"name": "キャベツ", "icon": "🥬", "limit": 7},
      {"name": "レタス", "icon": "🥗", "limit": 3},
      {"name": "たまねぎ", "icon": "🧅", "limit": 21},
      {"name": "にんじん", "icon": "🥕", "limit": 14},
      {"name": "もやし", "icon": "🌱", "limit": 2},
      {"name": "ブロッコリー", "icon": "🥦", "limit": 4},
    ],
    "果物": [
      {"name": "りんご", "icon": "🍎", "limit": 14},
      {"name": "バナナ", "icon": "🍌", "limit": 5},
      {"name": "いちご", "icon": "🍓", "limit": 2},
      {"name": "みかん", "icon": "🍊", "limit": 10},
    ],
    "飲み物": [
      {"name": "牛乳", "icon": "🥛", "limit": 5},
      {"name": "お茶", "icon": "🍵", "limit": 4},
      {"name": "ジュース", "icon": "🧃", "limit": 4},
      {"name": "コーヒー", "icon": "☕", "limit": 3},
      {"name": "炭酸水", "icon": "🥤", "limit": 7},
      {"name": "ビール", "icon": "🍺", "limit": 30},
    ],
    "調味料": [
      {"name": "マヨネーズ", "icon": "🧴", "limit": 30},
      {"name": "ケチャップ", "icon": "🍅", "limit": 30},
      {"name": "味噌", "icon": "🍲", "limit": 90},
      {"name": "醤油", "icon": "🍶", "limit": 60},
      {"name": "焼肉のタレ", "icon": "🧴", "limit": 30},
    ],
    "キノコ類": [
      {"name": "しいたけ", "icon": "🍄", "limit": 5},
      {"name": "しめじ", "icon": "🍄", "limit": 5},
      {"name": "えのき", "icon": "🍄", "limit": 3},
      {"name": "エリンギ", "icon": "🍄", "limit": 5},
    ],
    "お菓子": [
      {"name": "チョコレート", "icon": "🍫", "limit": 30},
      {"name": "アイスクリーム", "icon": "🍦", "limit": 60},
      {"name": "ケーキ", "icon": "🍰", "limit": 1},
      {"name": "ポテトチップス", "icon": "🥔", "limit": 20},
      {"name": "プリン", "icon": "🍮", "limit": 3},
    ],
  };

  String _selectedCategory = "肉類";
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
          IconButton(
            icon: Icon(Icons.settings, color: _dynamicTextColor),
            onPressed: _showSettingsDialog,
          ),
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

  // --- 1. 在庫一覧画面 ---
  Widget _buildInventoryView() {
    return inventory.isEmpty 
      ? Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: _dynamicTextColor, fontSize: 18)))
      : ListView.builder(
          itemCount: inventory.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final item = inventory[index];
            final daysLeft = _calculateDaysLeft(item["expiry"]);
            final isExpired = daysLeft < 0;

            return Card(
              color: isExpired ? Colors.red.withOpacity(0.4) : Colors.black38,
              child: ListTile(
                leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 26)),
                title: Text(item["name"], style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  isExpired ? "期限切れ！" : "あと $daysLeft 日",
                  style: TextStyle(color: isExpired ? Colors.redAccent : _dynamicTextColor.withOpacity(0.7)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                  onPressed: () {
                    _speak("${item["name"]}を使い切りましたな！お見事！");
                    setState(() { inventory.removeAt(index); _saveData(); });
                  },
                ),
              ),
            );
          },
        );
  }

  // --- 2. 登録画面（2段階連動プルダウン） ---
  Widget _buildAddView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリ選択（大分類）
          Text("1. カテゴリを選択", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: _dynamicTextColor, fontSize: 16),
              items: _foodMaster.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCategory = v!;
                  // カテゴリが変わったら、食材名の初期値をそのカテゴリの最初のアイテムにリセット
                  _selectedFoodName = _foodMaster[v]![0]["name"];
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // 食材選択（小分類）
          Text("2. 食材を選択", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: DropdownButton<String>(
              value: _selectedFoodName,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: Colors.grey[900],
              style: TextStyle(color: _dynamicTextColor, fontSize: 16),
              items: _foodMaster[_selectedCategory]!.map((f) => DropdownMenuItem(
                value: f["name"] as String, 
                child: Text("${f["icon"]} ${f["name"]} (目安: ${f["limit"]}日)")
              )).toList(),
              onChanged: (v) => setState(() => _selectedFoodName = v!),
            ),
          ),
          const SizedBox(height: 24),

          // 自由入力
          Text("3. 自由入力（名前を変えたい場合）", style: TextStyle(color: _dynamicTextColor, fontWeight: FontWeight.bold)),
          TextField(
            controller: _customFoodController,
            style: TextStyle(color: _dynamicTextColor),
            decoration: InputDecoration(
              hintText: "例: 特売の$_selectedFoodName",
              hintStyle: TextStyle(color: _dynamicTextColor.withOpacity(0.4)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _dynamicTextColor.withOpacity(0.5))),
            ),
          ),
          const SizedBox(height: 40),

          // 登録ボタン
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellowAccent, 
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () {
              final name = _customFoodController.text.isNotEmpty ? _customFoodController.text : _selectedFoodName;
              final masterData = _foodMaster[_selectedCategory]!.firstWhere((e) => e["name"] == _selectedFoodName);
              
              _speak(charSettings[modeIndex]["msg"]);
              
              setState(() {
                inventory.add({
                  "name": name,
                  "icon": masterData["icon"],
                  "expiry": DateTime.now().add(Duration(days: masterData["limit"])).toIso8601String(),
                });
              });

              _customFoodController.clear();
              _saveData();
              setState(() => _currentTabIndex = 0); // 在庫タブへ移動
            },
            child: const Text("冷蔵庫に収納する", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  // --- 3. API設定画面 ---
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
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _dynamicTextColor)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.yellowAccent)),
            ),
            onChanged: (v) { recipeApiKey = v; _saveData(); },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => js.context.callMethod('open', ['https://platform.openai.com/api-keys']), 
            child: const Text("キーの取得はこちら", style: TextStyle(color: Colors.cyanAccent))
          ),
        ],
      ),
    );
  }

  // アプリ設定ダイアログ
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
        children: [
          const Color(0xFF1B5E20), // 深緑
          const Color(0xFF0D47A1), // 深青
          const Color(0xFFB71C1C), // 深赤
          const Color(0xFF4A148C), // 紫
          const Color(0xFFE65100), // オレンジ
          Colors.black
        ].map((c) => GestureDetector(
          onTap: () { setState(() => customColor = c); _saveData(); Navigator.pop(ctx); },
          child: Container(width: 50, height: 50, color: c, margin: const EdgeInsets.all(4)),
        )).toList(),
      ),
    ));
  }
}