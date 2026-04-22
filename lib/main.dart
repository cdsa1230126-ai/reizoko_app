// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; // 食材マスターデータ
import 'package:http/http.dart' as http;

void main() {
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
  // --- 状態管理変数 ---
  int _tabIdx = 1; 
  int modeIndex = 0;
  List<dynamic> inventory = [], shoppingList = [];
  Color customColor = const Color(0xFF004400); 
  String _apiKey = "";
  bool _isListView = true;

  // AIレシピ用
  String _aiMood = "🥗 ヘルシー";
  String _aiResult = "";
  bool _isAiLoading = false;
  final List<String> moods = ["🥗 ヘルシー", "🍖 ガッツリ", "⏱️ 時短"];

  // 登録用一時変数
  String _cat = "肉類", _name = "鶏むね肉", _unit = "個";
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  double _count = 1.0;
  bool _isFav = false;
  final List<String> units = ["個", "g", "kg", "ml", "L", "本", "枚", "パック", "合", "玉", "袋"];

  // キャラクター設定
  final List<Map<String, dynamic>> chars = [
    {"n": "長老", "i": "🧓", "m": "フォッフォッフォ、良い食材じゃ。"},
    {"n": "博士", "i": "🧑‍⚕️", "m": "フム、実に興味深いデータだ。"},
    {"n": "商人", "i": "🕶️", "m": "まいど！活きのいいのが入ったね！"},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // --- API設定・誘導 ---
  void _promptApiKey() {
    TextEditingController c = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("AI設定 (Gemini API)", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: c,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "APIキーを貼り付け",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("閉じる")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FFFD4), foregroundColor: Colors.black),
            onPressed: () {
              setState(() { _apiKey = c.text; });
              _save();
              Navigator.pop(ctx);
              _showMsg("✅ APIキーを保存しました");
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  // --- AIレシピ生成 ---
  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) {
      _promptApiKey();
      return;
    }
    setState(() { _isAiLoading = true; _aiResult = ""; });
    final ingredients = inventory.map((e) => "${e['name']}(${e['count']}${e['unit']})").join(", ");
    final prompt = "あなたは${chars[modeIndex]["n"]}です。$ingredientsを使って気分が$_aiMoodになるレシピを1つ教えて。";

    try {
      final res = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}),
      );
      if (res.statusCode == 200) {
        setState(() { _aiResult = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text']; });
      } else {
        _promptApiKey();
      }
    } catch (e) {
      setState(() { _aiResult = "エラーが発生しました。"; });
    }
    setState(() { _isAiLoading = false; });
  }

  // --- データ永続化 ---
  void _save() async {
    final p = await SharedPreferences.getInstance();
    p.setString('inv', jsonEncode(inventory));
    p.setString('shop', jsonEncode(shoppingList));
    p.setInt('mode', modeIndex);
    p.setInt('color', customColor.value);
    p.setString('apiKey', _apiKey);
    p.setBool('isListView', _isListView);
  }

  void _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(p.getString('inv') ?? "[]");
      shoppingList = jsonDecode(p.getString('shop') ?? "[]");
      modeIndex = p.getInt('mode') ?? 0;
      int? savedColor = p.getInt('color');
      if (savedColor != null) { customColor = Color(savedColor); }
      _apiKey = p.getString('apiKey') ?? "";
      _isListView = p.getBool('isListView') ?? true;
    });
  }

  // --- 演出・便利機能 ---
  void _speak(String t) => js.context.callMethod('eval', ["window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"]);
  void _showMsg(String m) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.black87, behavior: SnackBarBehavior.floating)); }
  String _getIcon(String n) { for (var list in foodMaster.values) { for (var i in list) { if (i["name"] == n) return i["icon"]; } } return "📦"; }

  @override
  Widget build(BuildContext context) {
    bool isDark = customColor.computeLuminance() < 0.4;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    Color themeBtnColor = const Color(0xFF7FFFD4); 

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${chars[modeIndex]["i"]} ${chars[modeIndex]["n"]}の冷蔵庫", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black38,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(_isListView ? Icons.grid_view : Icons.view_list, color: textColor), onPressed: () => setState(() { _isListView = !_isListView; _save(); })),
          IconButton(icon: const Icon(Icons.vpn_key, color: Colors.amber), onPressed: _promptApiKey),
          IconButton(icon: Icon(Icons.palette, color: textColor), onPressed: _showSettings),
        ],
      ),
      body: [
        _buildInv(textColor, subTextColor),
        _buildReg(textColor, themeBtnColor),
        _buildShop(textColor, subTextColor),
        _buildRec(textColor, themeBtnColor)
      ][_tabIdx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx,
        onTap: (i) => setState(() => _tabIdx = i),
        backgroundColor: Colors.black,
        selectedItemColor: themeBtnColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AIレシピ"),
        ],
      ),
    );
  }

  // --- タブ1：在庫リスト ---
  Widget _buildInv(Color tc, Color stc) {
    if (inventory.isEmpty) return Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: tc, fontSize: 18)));
    return _isListView 
      ? ListView.builder(padding: const EdgeInsets.all(10), itemCount: inventory.length, itemBuilder: (ctx, i) => _buildTile(inventory[i], i, true, stc))
      : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8), itemCount: inventory.length, itemBuilder: (ctx, i) => _buildCard(inventory[i], i));
  }

  // --- タブ2：登録画面 ---
  Widget _buildReg(Color textColor, Color btnColor) {
    return SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepTile("1", "カテゴリー", textColor),
      _drop(foodMaster.keys.toList(), _cat, (v) { setState(() { _cat = v!; _name = foodMaster[v]![0]["name"]; }); }),
      const SizedBox(height: 15),
      _stepTile("2", "食材", textColor),
      InkWell(onTap: _showFoodSelector, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)), child: Row(children: [Text(_getIcon(_name), style: const TextStyle(fontSize: 24)), const SizedBox(width: 15), Text(_name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), const Icon(Icons.arrow_drop_down, color: Colors.white)]))),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_stepTile("3", "単位", textColor), _drop(units, _unit, (v) => setState(() => _unit = v!))])),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_stepTile("4", "期限", textColor), InkWell(onTap: () async {
          var p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730)));
          if (p != null) { setState(() => _date = p); }
        }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text("${_date.year}/${_date.month}/${_date.day}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))])),
      ]),
      const SizedBox(height: 15),
      _stepTile("5", "数量", textColor),
      TextField(style: const TextStyle(color: Colors.white, fontSize: 20), keyboardType: TextInputType.number, decoration: InputDecoration(filled: true, fillColor: Colors.black38, hintText: "1.0", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), onChanged: (v) => _count = double.tryParse(v) ?? 1.0),
      const SizedBox(height: 15),
      _stepTile("6", "お気に入り", textColor),
      Switch(value: _isFav, activeColor: btnColor, onChanged: (v) => setState(() => _isFav = v)),
      const SizedBox(height: 30),
      Row(children: [
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 64), backgroundColor: btnColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () {
          double step = (_unit == "g" || _unit == "ml") ? 50.0 : 1.0;
          setState(() { inventory.add({"name": _name, "icon": _getIcon(_name), "expiry": _date.toIso8601String(), "count": _count, "unit": _unit, "step": step, "isFavorite": _isFav}); });
          _speak("${chars[modeIndex]["m"]} $_nameを入れたぞ。"); _save();
        }, child: const Text("冷蔵庫へ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
        const SizedBox(width: 15),
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 64), backgroundColor: btnColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () {
          setState(() { shoppingList.add({"name": _name, "icon": _getIcon(_name), "count": _count, "unit": _unit}); });
          _save();
        }, child: const Text("買い物へ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
      ]),
    ]));
  }

  // --- タブ3：買い物リスト ---
  Widget _buildShop(Color tc, Color stc) {
    if (shoppingList.isEmpty) return Center(child: Text("買い物リストは空っぽじゃ。", style: TextStyle(color: tc, fontSize: 18)));
    return ListView.builder(padding: const EdgeInsets.all(10), itemCount: shoppingList.length, itemBuilder: (ctx, i) => _buildTile(shoppingList[i], i, false, stc));
  }

  // --- タブ4：AIレシピ ---
  Widget _buildRec(Color textColor, Color btnColor) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _aiMood == m ? btnColor : Colors.white10, foregroundColor: _aiMood == m ? Colors.black : Colors.white), onPressed: () => setState(() => _aiMood = m), child: Text(m, style: const TextStyle(fontSize: 10)))))).toList()),
        const SizedBox(height: 10),
        ElevatedButton.icon(icon: _isAiLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.auto_awesome), label: Text(_isAiLoading ? "考え中じゃ..." : "レシピを提案"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: _isAiLoading ? null : _generateRecipe),
      ])),
      Expanded(child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(child: Text(_aiResult.isEmpty ? "ここに提案が表示されるぞ。" : _aiResult, style: const TextStyle(color: Colors.white, fontSize: 16)))))
    ]);
  }

  // --- 共通パーツ ---
  Widget _buildTile(dynamic item, int index, bool isInv, Color stc) {
    return Card(color: Colors.black45, child: ListTile(
      leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
      title: Row(children: [Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), if (item["isFavorite"] == true) const Icon(Icons.star, color: Colors.yellowAccent, size: 16)]),
      subtitle: isInv ? Text("期限: ${item["expiry"].split('T')[0]}", style: TextStyle(color: stc, fontSize: 11)) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => _update(index, -(item["step"] ?? 1.0), isInv)),
        Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => _update(index, (item["step"] ?? 1.0), isInv)),
        if (!isInv) IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF7FFFD4)), onPressed: () { setState(() { inventory.add({...shoppingList[index], "expiry": DateTime.now().add(const Duration(days: 3)).toIso8601String()}); shoppingList.removeAt(index); _save(); }); }),
      ]),
    ));
  }

  Widget _buildCard(dynamic item, int index) {
    return Card(color: Colors.black45, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(item["icon"], style: const TextStyle(fontSize: 40)),
      Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white70)),
    ]));
  }

  void _update(int i, double d, bool isInv) {
    setState(() { var l = isInv ? inventory : shoppingList; l[i]["count"] += d; if (l[i]["count"] <= 0) { l.removeAt(i); } _save(); });
  }

  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("設定"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(3, (i) => ListTile(leading: Text(chars[i]["i"]), title: Text(chars[i]["n"]), onTap: () { setState(() => modeIndex = i); _save(); Navigator.pop(ctx); })),
    ])));
  }

  void _showFoodSelector() {
    var list = foodMaster[_cat] ?? [];
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => ListTile(title: Text(list[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() { _name = list[i]["name"]; }); Navigator.pop(ctx); })));
  }

  Widget _stepTile(String s, String t, Color tc) => Row(children: [CircleAvatar(radius: 12, backgroundColor: const Color(0xFF7FFFD4), child: Text(s, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(width: 10), Text(t, style: TextStyle(color: tc, fontWeight: FontWeight.bold))]);
  Widget _drop(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87, iconEnabledColor: Colors.white));
}