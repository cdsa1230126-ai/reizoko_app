// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart';
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
  int _tabIdx = 1; 
  int modeIndex = 0;
  List<dynamic> inventory = [], shoppingList = [];
  Color customColor = const Color(0xFF1B5E20);
  String _apiKey = "";

  // 表示モード管理 (true: リスト形式, false: でかいカード形式)
  bool _isListView = true;

  String _aiMood = "🥗 ヘルシー";
  String _aiResult = "";
  bool _isAiLoading = false;
  final List<String> moods = ["🥗 ヘルシー", "🍖 ガッツリ", "⏱️ 時短"];

  String _cat = "肉類", _name = "鶏むね肉", _unit = "個", _vUnit = "ml";
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  double _count = 1.0, _vol = 500.0;
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
      customColor = Color(p.getInt('color') ?? 0xFF1B5E20);
      _apiKey = p.getString('apiKey') ?? "";
      _isListView = p.getBool('isListView') ?? true;
    });
  }

  void _speak(String t) => js.context.callMethod('eval', [
        "window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"
      ]);

  String _getIcon(String n) {
    for (var list in foodMaster.values) {
      for (var i in list) { if (i["name"] == n) return i["icon"]; }
    }
    return "📦";
  }

  // 完了通知を表示する関数
  void _showCompleteMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orangeAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(
        title: Text("${chars[modeIndex]["i"]} ${chars[modeIndex]["n"]}の冷蔵庫", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black38,
        actions: [
          // 表示モード切り替えボタン
          if (_tabIdx == 0 || _tabIdx == 2) 
            IconButton(
              icon: Icon(_isListView ? Icons.grid_view : Icons.view_list, color: textColor),
              onPressed: () => setState(() { _isListView = !_isListView; _save(); }),
            ),
          IconButton(icon: const Icon(Icons.vpn_key, color: Colors.amber), onPressed: _showApiKeySetting),
          IconButton(icon: Icon(Icons.palette, color: textColor), onPressed: _showSettings),
        ],
      ),
      body: [_buildInv(textColor), _buildReg(textColor), _buildShop(textColor), _buildRec(textColor)][_tabIdx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx,
        onTap: (i) => setState(() => _tabIdx = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
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

  // --- 在庫タブ ---
  Widget _buildInv(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)));
    
    if (_isListView) {
      return ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: inventory.length,
        itemBuilder: (context, i) => _buildItemTile(inventory[i], i, true),
      );
    } else {
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85, mainAxisSpacing: 10, crossAxisSpacing: 10),
        itemCount: inventory.length,
        itemBuilder: (context, i) => _buildItemCard(inventory[i], i, true),
      );
    }
  }

  // --- 登録タブ ---
  Widget _buildReg(Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepTile("1", "カテゴリー", textColor),
        _drop(foodMaster.keys.toList(), _cat, (v) => setState(() { _cat = v!; _name = foodMaster[v]![0]["name"]; })),
        const SizedBox(height: 15),
        _stepTile("2", "食材", textColor),
        InkWell(onTap: _showFoodSelector, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)), child: Row(children: [Text(_getIcon(_name), style: const TextStyle(fontSize: 24)), const SizedBox(width: 15), Text(_name, style: const TextStyle(color: Colors.white, fontSize: 18)), const Spacer(), const Icon(Icons.arrow_drop_down, color: Colors.white)]))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_stepTile("3", "単位", textColor), _drop(units, _unit, (v) => setState(() => _unit = v!))])),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _stepTile("4", "期限", textColor),
            InkWell(onTap: () async {
              var p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730)));
              if (p != null) setState(() => _date = p);
            }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text("${_date.year}/${_date.month}/${_date.day}", style: const TextStyle(color: Colors.white))))
          ])),
        ]),
        const SizedBox(height: 15),
        _stepTile("5", "個数", textColor),
        Row(children: [
          Expanded(child: _drop(List.generate(30, (i) => (i + 1).toString()), _count.toInt().toString(), (v) => setState(() => _count = double.parse(v!)))),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => setState(() { if (_count > 1) _count--; })),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => setState(() => _count++)),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          _stepTile("6", "お気に入り登録", textColor),
          const SizedBox(width: 10),
          Switch(value: _isFav, activeColor: Colors.yellowAccent, onChanged: (v) => setState(() => _isFav = v)),
        ]),
        if (_cat == "飲み物") ...[
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "容量", labelStyle: TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black26), keyboardType: TextInputType.number, onChanged: (v) => _vol = double.tryParse(v) ?? 500)),
            const SizedBox(width: 10),
            Expanded(child: _drop(["ml", "L"], _vUnit, (v) => setState(() => _vUnit = v!))),
          ]),
        ],
        const SizedBox(height: 30),
        Row(children: [
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60), backgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () {
              setState(() { shoppingList.add({"name": _name, "icon": _getIcon(_name), "count": _count, "unit": _unit, "step": 1.0}); });
              _showCompleteMsg("🛒 買い物リストに登録完了！");
              _speak("買い物リストに入れたぞ。");
              _save();
            },
            child: const Text("買い物へ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () {
              double step = (_unit == "g" || _unit == "ml") ? 50.0 : (_unit == "合" ? 0.5 : 1.0);
              setState(() { 
                inventory.add({
                  "name": _name, "icon": _getIcon(_name), "expiry": _date.toIso8601String(), 
                  "count": _count, "unit": _unit, "step": step, "isFavorite": _isFav,
                  "vol": _vol, "vUnit": _vUnit
                }); 
              });
              _showCompleteMsg("🧊 冷蔵庫に登録完了！");
              _speak("${chars[modeIndex]["m"]} $_nameを入れたぞ。");
              _save();
            },
            child: const Text("冷蔵庫へ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )),
        ]),
      ]),
    );
  }

  // --- 買い物タブ ---
  Widget _buildShop(Color textColor) {
    if (shoppingList.isEmpty) return Center(child: Text("買うべきものはないぞ。", style: TextStyle(color: textColor, fontSize: 18)));
    return _isListView 
      ? ListView.builder(padding: const EdgeInsets.all(10), itemCount: shoppingList.length, itemBuilder: (ctx, i) => _buildItemTile(shoppingList[i], i, false))
      : GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: shoppingList.length,
          itemBuilder: (ctx, i) => _buildItemCard(shoppingList[i], i, false),
        );
  }

  // --- 共通部品: リスト形式のタイル ---
  Widget _buildItemTile(dynamic item, int index, bool isInventory) {
    final double step = (item["step"] ?? 1.0).toDouble();
    return Card(
      color: isInventory ? Colors.black45 : Colors.white12,
      child: ListTile(
        leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
        title: Row(children: [
          Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (item["isFavorite"] == true) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.star, color: Colors.yellowAccent, size: 18)),
        ]),
        subtitle: isInventory ? Text("期限: ${item["expiry"].split('T')[0]}", style: const TextStyle(color: Colors.white60, fontSize: 12)) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => _updateCount(index, -step, isInventory)),
          Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => _updateCount(index, step, isInventory)),
          if (!isInventory) IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 30), onPressed: () => _restock(index)),
        ]),
      ),
    );
  }

  // --- 共通部品: でかいカード形式 ---
  Widget _buildItemCard(dynamic item, int index, bool isInventory) {
    final double step = (item["step"] ?? 1.0).toDouble();
    return Container(
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (item["isFavorite"] == true) const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.star, color: Colors.yellowAccent, size: 16))),
        Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 5),
        Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        if (isInventory) Text("期限: ${item["expiry"].split('T')[0]}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => _updateCount(index, -step, isInventory)),
          Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => _updateCount(index, step, isInventory)),
        ]),
        if (!isInventory) ElevatedButton.icon(onPressed: () => _restock(index), icon: const Icon(Icons.check, size: 16), label: const Text("購入"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20)))
      ]),
    );
  }

  void _updateCount(int i, double delta, bool isInv) {
    setState(() {
      var list = isInv ? inventory : shoppingList;
      list[i]["count"] += delta;
      if (list[i]["count"] <= 0) {
        if (isInv) {
          shoppingList.add({ ...list[i], "count": 1.0 });
          _speak("${list[i]["name"]}が切れたぞ。");
        }
        list.removeAt(i);
      }
      _save();
    });
  }

  void _restock(int index) {
    setState(() {
      final item = shoppingList[index];
      inventory.add({ ...item, "expiry": DateTime.now().add(const Duration(days: 3)).toIso8601String() });
      shoppingList.removeAt(index);
      _speak("${item["name"]}を補充したぞ。");
      _save();
    });
  }

  // --- AIレシピ / 設定などは初期コードのまま ---
  Widget _buildRec(Color textColor) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) {
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _aiMood == m ? Colors.yellowAccent : Colors.white10, foregroundColor: _aiMood == m ? Colors.black : Colors.white), onPressed: () => setState(() => _aiMood = m), child: Text(m, style: const TextStyle(fontSize: 10)))));
        }).toList()),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: _isAiLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.auto_awesome),
          label: Text(_isAiLoading ? "考え中じゃ..." : "レシピを提案してもらう"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: _isAiLoading ? null : _generateRecipe,
        ),
      ])),
      Expanded(child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(child: Text(_aiResult.isEmpty ? "レシピはここに表示されるぞ。" : _aiResult, style: const TextStyle(color: Colors.white, fontSize: 16)))))
    ]);
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("APIキーを設定してください"))); return; }
    setState(() { _isAiLoading = true; _aiResult = ""; });
    final ingredients = inventory.map((e) => "${e['name']}(${e['count']}${e['unit']})").join(", ");
    final charName = chars[modeIndex]["n"];
    final prompt = "あなたは$charNameです。冷蔵庫にある「$ingredients」を使って、気分が「$_aiMood」にぴったりの料理レシピを1つ提案してください。$charNameらしい口調で教えてください。";
    try {
      final response = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));
      if (response.statusCode == 200) { setState(() { _aiResult = jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text']; }); _speak("レシピができたぞ。"); }
    } catch (e) { setState(() => _aiResult = "エラーが発生したわい。"); }
    setState(() => _isAiLoading = false);
  }

  void _showApiKeySetting() {
    TextEditingController controller = TextEditingController(text: _apiKey);
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("🔑 API設定", style: TextStyle(color: Colors.white)), content: TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Gemini API Key")), actions: [ElevatedButton(onPressed: () { setState(() => _apiKey = controller.text.trim()); _save(); Navigator.pop(ctx); }, child: const Text("保存"))]));
  }

  void _showFoodSelector() {
    var foodList = foodMaster[_cat] ?? [];
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: foodList.length, itemBuilder: (context, i) => ListTile(leading: Text(foodList[i]["icon"], style: const TextStyle(fontSize: 24)), title: Text(foodList[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() { _name = foodList[i]["name"]; _date = DateTime.now().add(Duration(days: foodList[i]["limit"])); }); Navigator.pop(ctx); })));
  }

  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("設定"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(3, (i) => ListTile(leading: Text(chars[i]["i"]), title: Text(chars[i]["n"]), onTap: () { setState(() => modeIndex = i); Navigator.pop(ctx); })),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Colors.green[900]!, Colors.blue[900]!, Colors.red[900]!, Colors.orange[900]!].map((c) => InkWell(onTap: () { setState(() => customColor = c); _save(); Navigator.pop(ctx); }, child: Container(width: 30, height: 30, color: c))).toList())
    ])));
  }

  Widget _stepTile(String step, String text, Color textColor) => Row(children: [
    CircleAvatar(radius: 12, backgroundColor: Colors.yellowAccent, child: Text(step, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
    const SizedBox(width: 10),
    Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
  ]);

  Widget _drop(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white)));
}