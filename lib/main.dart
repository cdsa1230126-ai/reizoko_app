// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart'; // カテゴリー・食材・アイコンが入った外部ファイル
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
  // --- 状態管理 ---
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

  // 登録用
  String _cat = "肉類", _name = "鶏むね肉", _unit = "個";
  // 初期期限をfoodMasterから取得するように改善
  DateTime _date = DateTime.now().add(const Duration(days: 2)); 
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
    _load();
  }

  // --- 設定（背景色・キャラ・表示モード） ---
  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("アプリ設定", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("背景カラー", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _colorBtn(const Color(0xFF004400)), _colorBtn(const Color(0xFF440000)),
              _colorBtn(const Color(0xFF000044)), _colorBtn(const Color(0xFF222222)),
            ]),
            const Divider(color: Colors.white24, height: 30),
            const Text("パートナー", style: TextStyle(color: Colors.white70)),
            ...List.generate(3, (i) => ListTile(
              leading: Text(chars[i]["i"], style: const TextStyle(fontSize: 24)),
              title: Text(chars[i]["n"], style: const TextStyle(color: Colors.white)),
              onTap: () { setState(() => modeIndex = i); _save(); Navigator.pop(ctx); },
            )),
          ],
        ),
      ),
    );
  }

  Widget _colorBtn(Color c) => InkWell(
    onTap: () { setState(() => customColor = c); _save(); Navigator.pop(context); },
    child: CircleAvatar(backgroundColor: c, radius: 18, child: customColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
  );

  // --- 計算ロジック ---
  void _consumeItem(int index) {
    final item = inventory[index];
    bool isSpecial = item["name"].contains("米") || item["unit"] == "g" || item["unit"] == "ml" || item["unit"] == "L";
    if (isSpecial) { _showMeasureDialog(index); }
    else { setState(() { item["count"] -= 1.0; if (item["count"] <= 0) _moveToShopping(index); _save(); }); }
  }

  void _showMeasureDialog(int index) {
    final item = inventory[index];
    final TextEditingController cont = TextEditingController();
    bool isRice = item["name"].contains("米");
    bool isLiquid = item["unit"] == "ml" || item["unit"] == "L";

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text("${item["name"]}を使う", style: const TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isRice ? "何合使いましたか？" : "使用量を入力 (${item["unit"]})", style: const TextStyle(color: Colors.white70)),
        TextField(controller: cont, autofocus: true, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
        if (isLiquid) ...[
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton(onPressed: () => _applyMeasure(index, cont.text, "大さじ"), child: const Text("大さじ")),
            ElevatedButton(onPressed: () => _applyMeasure(index, cont.text, "小さじ"), child: const Text("小さじ")),
          ])
        ]
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("キャンセル")),
        ElevatedButton(onPressed: () => _applyMeasure(index, cont.text, "確定"), child: const Text("決定")),
      ],
    ));
  }

  void _applyMeasure(int index, String val, String type) {
    double input = double.tryParse(val) ?? 0;
    if (input <= 0) return;
    setState(() {
      var item = inventory[index];
      double sub = (item["name"].contains("米")) ? input * 0.15 : (type == "大さじ") ? input * 15 : (type == "小さじ") ? input * 5 : input;
      if (item["unit"] == "L" && (type == "大さじ" || type == "小さじ")) sub /= 1000;
      item["count"] -= sub;
      if (item["count"] <= 0) _moveToShopping(index);
      _save();
    });
    Navigator.pop(context);
  }

  void _moveToShopping(int i) {
    shoppingList.add({"name": inventory[i]["name"], "icon": inventory[i]["icon"], "count": 1.0, "unit": inventory[i]["unit"]});
    inventory.removeAt(i);
    _speak("${shoppingList.last["name"]}を使い切ったぞ。リストに追加した。");
  }

  // --- 保存・同期 ---
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
      int? cVal = p.getInt('color');
      if (cVal != null) customColor = Color(cVal);
      _apiKey = p.getString('apiKey') ?? "";
      _isListView = p.getBool('isListView') ?? true;
    });
  }

  void _speak(String t) => js.context.callMethod('eval', ["window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"]);

  // --- メイン UI ---
  @override
  Widget build(BuildContext context) {
    bool isDark = customColor.computeLuminance() < 0.4;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color themeBtnColor = const Color(0xFF7FFFD4);

    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${chars[modeIndex]["i"]} ${chars[modeIndex]["n"]}の冷蔵庫", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black38,
        actions: [
          IconButton(icon: Icon(_isListView ? Icons.grid_view : Icons.view_list, color: textColor), onPressed: () => setState(() { _isListView = !_isListView; _save(); })),
          IconButton(icon: const Icon(Icons.vpn_key, color: Colors.amber), onPressed: _promptApiKey),
          IconButton(icon: Icon(Icons.palette, color: textColor), onPressed: _showSettings),
        ],
      ),
      body: [
        _buildInventory(textColor),
        _buildRegistration(textColor, themeBtnColor),
        _buildShoppingList(textColor),
        _buildAiTab(textColor, themeBtnColor),
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
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AIレシピ"),
        ],
      ),
    );
  }

  // 在庫タブ
  Widget _buildInventory(Color tc) {
    if (inventory.isEmpty) return Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: tc, fontSize: 18)));
    
    return _isListView 
      ? ListView.builder(padding: const EdgeInsets.all(10), itemCount: inventory.length, itemBuilder: (ctx, i) => _itemTile(inventory[i], i))
      : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85), itemCount: inventory.length, itemBuilder: (ctx, i) => _itemCard(inventory[i], i));
  }

  // 在庫：リスト形式（期限による色の変化を追加）
  Widget _itemTile(dynamic item, int i) {
    bool isSpecial = item["name"].contains("米") || item["unit"] == "g" || item["unit"] == "ml" || item["unit"] == "L";
    
    // 消費期限の判定
    DateTime expiryDate = DateTime.parse(item["expiry"]);
    bool isExpired = expiryDate.isBefore(DateTime.now());
    bool isUrgent = expiryDate.isBefore(DateTime.now().add(const Duration(days: 2)));

    return Card(
      color: Colors.black45,
      child: ListTile(
        leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
        title: Row(children: [
          Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (item["isFav"] == true) const Icon(Icons.star, color: Colors.amber, size: 16),
        ]),
        subtitle: Text(
          "期限: ${item["expiry"].split('T')[0]}", 
          style: TextStyle(
            color: isExpired ? Colors.redAccent : (isUrgent ? Colors.orangeAccent : Colors.white38),
            fontSize: 11,
            fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
          )
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(isSpecial ? Icons.calculate : Icons.remove_circle_outline, color: Colors.white70), onPressed: () => _consumeItem(i)),
          Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => setState(() { item["count"] += 1.0; _save(); })),
        ]),
      ),
    );
  }

  // 在庫：グリッド形式（期限切れの背景色変化を追加）
  Widget _itemCard(dynamic item, int i) {
    DateTime expiryDate = DateTime.parse(item["expiry"]);
    bool isExpired = expiryDate.isBefore(DateTime.now());

    return Card(
      color: isExpired ? Colors.red.withOpacity(0.3) : Colors.black45,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (item["isFav"] == true) const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.star, color: Colors.amber, size: 16))),
        Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Color(0xFF7FFFD4))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white60, size: 20), onPressed: () => _consumeItem(i)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white60, size: 20), onPressed: () => setState(() { item["count"] += 1.0; _save(); })),
        ])
      ]),
    );
  }

  // 登録タブ
  Widget _buildRegistration(Color tc, Color bc) {
    return SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepHeader("1", "カテゴリー", tc),
      _dropdown(foodMaster.keys.toList(), _cat, (v) {
        setState(() { 
          _cat = v!; 
          var firstItem = foodMaster[v]![0];
          _name = firstItem["name"];
          // カテゴリ変更時に期限を自動更新
          _date = DateTime.now().add(Duration(days: firstItem["limit"]));
        });
      }),
      const SizedBox(height: 15),
      _stepHeader("2", "食材を選ぶ", tc),
      InkWell(onTap: _showFoodSelector, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)), child: Row(children: [Text(_name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), const Icon(Icons.arrow_drop_down, color: Colors.white)]))),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_stepHeader("3", "単位", tc), _dropdown(units, _unit, (v) => setState(() => _unit = v!))])),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_stepHeader("4", "期限", tc), InkWell(onTap: () async {
          var p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
          if (p != null) setState(() => _date = p);
        }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text("${_date.year}/${_date.month}/${_date.day}", style: const TextStyle(color: Colors.white))))])),
      ]),
      const SizedBox(height: 15),
      _stepHeader("5", "数量", tc),
      TextField(style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: const InputDecoration(filled: true, fillColor: Colors.black38, hintText: "1.0", hintStyle: TextStyle(color: Colors.white24)), onChanged: (v) => _count = double.tryParse(v) ?? 1.0),
      const SizedBox(height: 10),
      Row(children: [const Text("お気に入り", style: TextStyle(color: Colors.white70)), Switch(value: _isFav, activeColor: bc, onChanged: (v) => setState(() => _isFav = v))]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60), backgroundColor: bc, foregroundColor: Colors.black), onPressed: () {
          setState(() => inventory.add({"name": _name, "icon": _getIcon(_name), "count": _count, "unit": _unit, "expiry": _date.toIso8601String(), "isFav": _isFav}));
          _speak("${chars[modeIndex]["m"]} $_nameを入れたぞ。"); _save();
        }, child: const Text("冷蔵庫へ", style: TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(width: 15),
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60), backgroundColor: bc, foregroundColor: Colors.black), onPressed: () {
          setState(() => shoppingList.add({"name": _name, "icon": _getIcon(_name), "count": _count, "unit": _unit}));
          _save();
        }, child: const Text("買い物へ", style: TextStyle(fontWeight: FontWeight.bold)))),
      ]),
    ]));
  }

  // 買い物タブ
  Widget _buildShoppingList(Color tc) {
    if (shoppingList.isEmpty) return Center(child: Text("買い物リストは空じゃ。", style: TextStyle(color: tc)));
    return ListView.builder(padding: const EdgeInsets.all(10), itemCount: shoppingList.length, itemBuilder: (ctx, i) => Card(color: Colors.black45, child: ListTile(leading: Text(shoppingList[i]["icon"] ?? "🛒"), title: Text(shoppingList[i]["name"], style: const TextStyle(color: Colors.white)), trailing: IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF7FFFD4), size: 32), onPressed: () {
      setState(() { 
        // 買い物完了時はマスタから期限を引いてくる
        int limitDays = _getLimit(shoppingList[i]["name"]);
        inventory.add({...shoppingList[i], "expiry": DateTime.now().add(Duration(days: limitDays)).toIso8601String()}); 
        shoppingList.removeAt(i); 
        _save(); 
      });
    }))));
  }

  // AIタブ
  Widget _buildAiTab(Color tc, Color bc) => Column(children: [
    Padding(padding: const EdgeInsets.all(15), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) => ChoiceChip(label: Text(m), selected: _aiMood == m, onSelected: (s) => setState(() => _aiMood = m))).toList()),
      const SizedBox(height: 10),
      ElevatedButton.icon(icon: const Icon(Icons.auto_awesome), label: Text(_isAiLoading ? "思考中..." : "レシピを提案"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber, foregroundColor: Colors.black), onPressed: _isAiLoading ? null : _generateRecipe),
    ])),
    Expanded(child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(child: Text(_aiResult.isEmpty ? "ここに提案が出るぞ。" : _aiResult, style: const TextStyle(color: Colors.white)))))
  ]);

  void _promptApiKey() {
    TextEditingController c = TextEditingController(text: _apiKey);
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("API設定", style: TextStyle(color: Colors.white)), content: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Gemini API Key")), actions: [ElevatedButton(onPressed: () { setState(() => _apiKey = c.text); _save(); Navigator.pop(ctx); }, child: const Text("保存"))]));
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) { _promptApiKey(); return; }
    if (inventory.isEmpty) { setState(() => _aiResult = "冷蔵庫が空っぽじゃ。"); return; }
    setState(() { _isAiLoading = true; _aiResult = ""; });
    
    // プロンプトに数量も含めるように改善
    final items = inventory.map((e) => "${e['name']}(${e['count']}${e['unit']})").join(',');
    final prompt = "あなたは${chars[modeIndex]["n"]}です。${items}を使って${_aiMood}なレシピを教えて。手順も簡潔に。";
    
    try {
      final res = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));
      if (res.statusCode == 200) {
        setState(() => _aiResult = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text']);
      } else {
        setState(() => _aiResult = "APIエラーが発生したぞ。");
      }
    } catch (e) { setState(() => _aiResult = "通信エラーじゃ。"); }
    setState(() => _isAiLoading = false);
  }

  void _showFoodSelector() {
    var list = foodMaster[_cat] ?? [];
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => ListTile(
      title: Text(list[i]["name"], style: const TextStyle(color: Colors.white)), 
      onTap: () { 
        setState(() { 
          _name = list[i]["name"]; 
          // 食材選択時にマスタのlimitを反映
          _date = DateTime.now().add(Duration(days: list[i]["limit"]));
        }); 
        Navigator.pop(ctx); 
      }
    )));
  }

  String _getIcon(String n) { for (var l in foodMaster.values) { for (var i in l) { if (i["name"] == n) return i["icon"]; } } return "📦"; }
  int _getLimit(String n) { for (var l in foodMaster.values) { for (var i in l) { if (i["name"] == n) return i["limit"]; } } return 3; }
  
  Widget _stepHeader(String s, String t, Color tc) => Row(children: [CircleAvatar(radius: 12, backgroundColor: const Color(0xFF7FFFD4), child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(width: 10), Text(t, style: TextStyle(color: tc, fontWeight: FontWeight.bold))]);
  Widget _dropdown(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87));
}