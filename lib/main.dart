// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; 
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: ReizokoApp(), debugShowCheckedModeBanner: false));
}

class ReizokoApp extends StatefulWidget {
  const ReizokoApp({super.key});
  @override
  State<ReizokoApp> createState() => _ReizokoAppState();
}

class _ReizokoAppState extends State<ReizokoApp> {
  int _tabIdx = 1;
  int modeIndex = 0;
  List<dynamic> inventory = [], shoppingList = [], favoriteRecipes = [];
  Color customColor = const Color(0xFF004400);
  String _apiKey = "";
  bool _isListView = true;

  String _aiMood = "🥗 ヘルシー";
  String _aiResult = "";
  bool _isAiLoading = false;
  final List<String> moods = ["🥗 ヘルシー", "🍖 ガッツリ", "⏱️ 時短"];

  String _cat = "肉類", _name = "鶏むね肉", _unit = "個", _loc = "冷蔵";
  DateTime _date = DateTime.now().add(const Duration(days: 3));
  double _count = 1.0;
  bool _isFav = false;
  final List<String> units = ["個", "g", "kg", "ml", "L", "本", "枚", "パック", "合", "玉", "袋"];

  final List<Map<String, dynamic>> chars = [
    {"n": "長老", "i": "🧓", "m": "フォッフォッフォ、良い食材じゃ。"},
    {"n": "博士", "i": "🧑‍⚕️", "m": "フム、実に興味深いデータだ。"},
    {"n": "商人", "i": "🕶️", "m": "まいど！活きのいいのが入ったね！"},
  ];

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (_apiKey.isEmpty) Future.delayed(Duration.zero, () => _showTutorial());
    });
  }

  // --- チュートリアル ---
  void _showTutorial() {
    int step = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStep) {
          final pages = [
            {"t": "食材の登録", "m": "「登録」タブから冷蔵庫や買い物リストへ追加できます。", "i": Icons.add_circle_outline},
            {"t": "AIキーの取得", "m": "AIレシピにはキーが必要です。下のボタンから取得ページへ飛べます。", "i": Icons.vpn_key},
          ];
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(children: [Icon(pages[step]["i"] as IconData, color: Colors.amber), const SizedBox(width: 10), Text(pages[step]["t"] as String, style: const TextStyle(color: Colors.white))]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(pages[step]["m"] as String, style: const TextStyle(color: Colors.white70)),
              if (step == 1) Padding(padding: const EdgeInsets.only(top: 15), child: ElevatedButton(onPressed: () => js.context.callMethod('open', ['https://aistudio.google.com/app/apikey']), child: const Text("API取得ページを開く"))),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("スキップ")),
              ElevatedButton(onPressed: () => step < pages.length - 1 ? setStep(() => step++) : {Navigator.pop(ctx), _promptApiKey()}, child: Text(step == pages.length - 1 ? "完了" : "次へ")),
            ],
          );
        },
      ),
    );
  }

  // --- 計量・お米計算ロジック ---
  void _consumeItem(int index) {
    final item = inventory[index];
    bool isSpecial = item["name"].contains("米") || ["g", "ml", "L", "kg"].contains(item["unit"]);
    if (isSpecial) {
      _showMeasureDialog(index);
    } else {
      setState(() {
        item["count"] -= 1.0;
        if (item["count"] <= 0) _moveToShopping(index);
        _save();
      });
    }
  }

  void _showMeasureDialog(int index) {
    final item = inventory[index];
    final TextEditingController cont = TextEditingController();
    bool isLiquid = ["ml", "L"].contains(item["unit"]);
    bool isRice = item["name"].contains("米");

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text("${item["name"]}を使う", style: const TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: cont, autofocus: true, style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: isRice ? "何合使いましたか？" : "使用量 (${item["unit"]})",
            labelStyle: const TextStyle(color: Colors.white70),
          )
        ),
        if (isLiquid) ...[
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton(onPressed: () => _applyMeasure(index, cont.text, "大さじ"), child: const Text("大さじ")),
            ElevatedButton(onPressed: () => _applyMeasure(index, cont.text, "小さじ"), child: const Text("小さじ")),
          ])
        ]
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("戻る")),
        ElevatedButton(onPressed: () => _applyMeasure(index, cont.text, "確定"), child: const Text("確定")),
      ],
    ));
  }

  void _applyMeasure(int index, String val, String type) {
    double input = double.tryParse(val) ?? 0;
    setState(() {
      var item = inventory[index];
      double sub = 0;
      if (item["name"].contains("米")) {
        sub = input * 0.15; // 1合=0.15kg
      } else if (type == "大さじ") {
        sub = 15.0;
      } else if (type == "小さじ") {
        sub = 5.0;
      } else {
        sub = input;
      }

      if (item["unit"] == "L" && (type == "大さじ" || type == "小さじ")) sub /= 1000;
      item["count"] -= sub;
      if (item["count"] <= 0) _moveToShopping(index);
      _save();
    });
    Navigator.pop(context);
  }

  void _moveToShopping(int i) {
    shoppingList.add({...inventory[i], "count": 1.0});
    _speak("${inventory[i]["name"]}を使い切ったぞ。リストに追加した。");
    inventory.removeAt(i);
    _save();
  }

  // --- UI構築 ---
  @override
  Widget build(BuildContext context) {
    bool isDark = customColor.computeLuminance() < 0.4;
    Color tc = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${chars[modeIndex]["i"]} ${chars[modeIndex]["n"]}の冷蔵庫", style: TextStyle(color: tc, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black38,
        actions: [
          IconButton(icon: Icon(_isListView ? Icons.grid_view : Icons.view_list, color: tc), onPressed: () => setState(() { _isListView = !_isListView; _save(); })),
          IconButton(icon: const Icon(Icons.settings, color: Colors.amber), onPressed: _showSettings),
        ],
      ),
      body: [
        _buildListTab(inventory, true, tc),
        _buildRegistration(tc),
        _buildListTab(shoppingList, false, tc),
        _buildAiTab(tc),
      ][_tabIdx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx, onTap: (i) => setState(() => _tabIdx = i),
        backgroundColor: Colors.black, selectedItemColor: const Color(0xFF7FFFD4), unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AIレシピ"),
        ],
      ),
    );
  }

  Widget _buildListTab(List<dynamic> list, bool isInv, Color tc) {
    if (list.isEmpty) return Center(child: Text(isInv ? "中身は空じゃ。" : "買うものはないぞ。", style: TextStyle(color: tc)));
    return _isListView 
      ? ListView.builder(padding: const EdgeInsets.all(10), itemCount: list.length, itemBuilder: (ctx, i) => _itemTile(list[i], i, isInv))
      : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8), itemCount: list.length, itemBuilder: (ctx, i) => _itemCard(list[i], i, isInv));
  }

  Widget _itemTile(dynamic item, int i, bool isInv) {
    // 期限による背景色変更
    Color cardColor = Colors.black45;
    if (isInv && item["expiry"] != null) {
      final diff = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
      if (diff < 0) cardColor = Colors.red.withOpacity(0.4);
      else if (diff <= 2) cardColor = Colors.orange.withOpacity(0.4);
    }

    return Card(color: cardColor, child: ListTile(
      leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
      title: Row(children: [Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), if (item["isFav"] == true) const Icon(Icons.star, color: Colors.amber, size: 16)]),
      subtitle: Text("${item["count"]}${item["unit"]} / ${item["loc"] ?? '冷蔵'}\n期限: ${item["expiry"].split('T')[0]}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
      trailing: isInv 
        ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => _consumeItem(i))
        : IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF7FFFD4)), onPressed: () => _buyItem(i)),
    ));
  }

  Widget _itemCard(dynamic item, int i, bool isInv) {
    return Card(color: Colors.black45, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (item["isFav"] == true) const Icon(Icons.star, color: Colors.amber, size: 14),
      Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 40)),
      Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Color(0xFF7FFFD4))),
      Text(item["loc"] ?? "冷蔵", style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 5),
      isInv 
        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white60), onPressed: () => _consumeItem(i)),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white60), onPressed: () => setState(() { item["count"] += 1.0; _save(); })),
          ])
        : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FFFD4), foregroundColor: Colors.black), onPressed: () => _buyItem(i), child: const Text("購入")),
    ]));
  }

  void _buyItem(int index) {
    setState(() {
      inventory.add({...shoppingList[index], "expiry": DateTime.now().add(const Duration(days: 3)).toIso8601String()});
      shoppingList.removeAt(index);
      _sortInventory();
      _save();
    });
  }

  // --- 登録タブ ---
  Widget _buildRegistration(Color tc) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label("1. カテゴリー"),
      _dropdown(foodMaster.keys.toList(), _cat, (v) => setState(() { _cat = v!; _name = foodMaster[v]![0]["name"]; })),
      const SizedBox(height: 15),
      _label("2. 食材"),
      ListTile(tileColor: Colors.black38, title: Text(_name, style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.arrow_drop_down, color: Colors.white), onTap: _showFoodSelector),
      const SizedBox(height: 15),
      _label("3. 保管場所"),
      _dropdown(["冷蔵", "冷凍", "野菜室", "常温"], _loc, (v) => setState(() => _loc = v!)),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label("4. 単位"), _dropdown(units, _unit, (v) => setState(() => _unit = v!))])),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label("5. 期限"), ElevatedButton(onPressed: () async { var p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365))); if (p != null) setState(() => _date = p); }, child: Text("${_date.year}/${_date.month}/${_date.day}"))])),
      ]),
      const SizedBox(height: 15),
      _label("6. 数量"),
      TextField(style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(filled: true, fillColor: Colors.black38, hintText: "1.0"), onChanged: (v) => _count = double.tryParse(v) ?? 1.0),
      Row(children: [const Text("お気に入り", style: TextStyle(color: Colors.white70)), Switch(value: _isFav, activeColor: Colors.amber, onChanged: (v) => setState(() => _isFav = v))]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: () => _add(true), icon: const Icon(Icons.kitchen), label: const Text("在庫へ"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FFFD4), foregroundColor: Colors.black, minimumSize: const Size(0, 60)))),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton.icon(onPressed: () => _add(false), icon: const Icon(Icons.shopping_cart), label: const Text("買い物へ"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size(0, 60)))),
      ]),
    ]));
  }

  void _add(bool toInv) {
    var data = {"name": _name, "icon": _getIcon(_name), "count": _count, "unit": _unit, "expiry": _date.toIso8601String(), "isFav": _isFav, "loc": _loc};
    setState(() { if (toInv) inventory.add(data); else shoppingList.add(data); _sortInventory(); });
    _speak("$_nameを追加したぞ。"); _save();
  }

  // --- AIタブ ---
  Widget _buildAiTab(Color tc) => Column(children: [
    Padding(padding: const EdgeInsets.all(15), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) => ChoiceChip(label: Text(m), selected: _aiMood == m, onSelected: (s) => setState(() => _aiMood = m))).toList()),
      const SizedBox(height: 10),
      ElevatedButton.icon(icon: const Icon(Icons.auto_awesome), label: Text(_isAiLoading ? "思考中..." : "レシピ提案"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: _isAiLoading ? null : _generateRecipe),
    ])),
    Expanded(child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(child: Column(children: [
      Text(_aiResult.isEmpty ? "提案を待っておるぞ。" : _aiResult, style: const TextStyle(color: Colors.white, height: 1.5)),
      if (_aiResult.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 15), child: ElevatedButton.icon(onPressed: _saveRecipe, icon: const Icon(Icons.bookmark), label: const Text("このレシピを保存する")))
    ]))))
  ]);

  void _saveRecipe() {
    setState(() => favoriteRecipes.add({"title": "$_aiMoodのレシピ", "body": _aiResult, "date": DateFormat('MM/dd').format(DateTime.now())}));
    _save(); _speak("レシピを保存したぞ。設定から見れるぞい。");
  }

  // --- 設定画面 ---
  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900], title: const Text("アプリ設定", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.book, color: Colors.amber), title: const Text("保存したレシピ", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); _showRecipeBook(); }),
        ListTile(leading: const Icon(Icons.open_in_new, color: Colors.amber), title: const Text("APIキーを取得", style: TextStyle(color: Colors.white)), onTap: () => js.context.callMethod('open', ['https://aistudio.google.com/app/apikey'])),
        ListTile(leading: const Icon(Icons.vpn_key, color: Colors.amber), title: const Text("APIキーを保存", style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(ctx); _promptApiKey(); }),
        const Divider(color: Colors.white24),
        ...List.generate(3, (i) => ListTile(leading: Text(chars[i]["i"]), title: Text(chars[i]["n"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() => modeIndex = i); _save(); Navigator.pop(ctx); })),
      ])),
    ));
  }

  void _showRecipeBook() {
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => favoriteRecipes.isEmpty ? const Center(child: Text("レシピはありません", style: TextStyle(color: Colors.white))) : ListView.builder(itemCount: favoriteRecipes.length, itemBuilder: (ctx, i) => ListTile(
      title: Text(favoriteRecipes[i]["title"], style: const TextStyle(color: Colors.white)),
      subtitle: Text(favoriteRecipes[i]["date"], style: const TextStyle(color: Colors.white38)),
      onTap: () => showDialog(context: context, builder: (d) => AlertDialog(backgroundColor: Colors.grey[900], title: Text(favoriteRecipes[i]["title"]), content: SingleChildScrollView(child: Text(favoriteRecipes[i]["body"], style: const TextStyle(color: Colors.white))), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text("閉じる")), TextButton(onPressed: () { setState(() => favoriteRecipes.removeAt(i)); _save(); Navigator.pop(d); Navigator.pop(ctx); }, child: const Text("削除", style: TextStyle(color: Colors.red)))]))
    )));
  }

  // --- システム・保存 ---
  void _promptApiKey() {
    TextEditingController c = TextEditingController(text: _apiKey);
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("API Key設定", style: TextStyle(color: Colors.white)), content: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(fillColor: Colors.white10, filled: true)), actions: [ElevatedButton(onPressed: () { setState(() => _apiKey = c.text); _save(); Navigator.pop(ctx); }, child: const Text("保存"))]));
  }

  void _sortInventory() {
    inventory.sort((a, b) => (a['expiry'] ?? "9999-12-31").compareTo(b['expiry'] ?? "9999-12-31"));
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) { _promptApiKey(); return; }
    setState(() { _isAiLoading = true; _aiResult = ""; });
    try {
      final res = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": "あなたは${chars[modeIndex]["n"]}です。${inventory.map((e)=>e['name']).join(',')}で${_aiMood}なレシピを作って。"}]}]}));
      setState(() => _aiResult = jsonDecode(utf8.decode(res.bodyBytes))['candidates'][0]['content']['parts'][0]['text']);
    } catch (e) { setState(() => _aiResult = "エラーじゃ。キーを確認してくれ。"); }
    setState(() => _isAiLoading = false);
  }

  void _save() async { final p = await SharedPreferences.getInstance(); p.setString('inv', jsonEncode(inventory)); p.setString('shop', jsonEncode(shoppingList)); p.setString('fav_recipes', jsonEncode(favoriteRecipes)); p.setInt('mode', modeIndex); p.setInt('color', customColor.value); p.setString('apiKey', _apiKey); p.setBool('isListView', _isListView); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); setState(() { inventory = jsonDecode(p.getString('inv') ?? "[]"); shoppingList = jsonDecode(p.getString('shop') ?? "[]"); favoriteRecipes = jsonDecode(p.getString('fav_recipes') ?? "[]"); modeIndex = p.getInt('mode') ?? 0; int? cVal = p.getInt('color'); if (cVal != null) customColor = Color(cVal); _apiKey = p.getString('apiKey') ?? ""; _isListView = p.getBool('isListView') ?? true; _sortInventory(); }); }
  void _speak(String t) => js.context.callMethod('eval', ["window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"]);
  void _showFoodSelector() { var list = foodMaster[_cat] ?? []; showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => ListTile(title: Text(list[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() => _name = list[i]["name"]); Navigator.pop(ctx); }))); }
  String _getIcon(String n) { for (var l in foodMaster.values) { for (var i in l) { if (i["name"] == n) return i["icon"]; } } return "📦"; }
  Widget _label(String s) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(s, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)));
  Widget _dropdown(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87));
}