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
  int _tabIdx = 0; 
  int modeIndex = 0;
  List<dynamic> inventory = [], shoppingList = [];
  Color customColor = const Color(0xFF1B5E20);
  String _apiKey = "";

  String _aiMood = "🥗 ヘルシー";
  String _aiResult = "";
  bool _isAiLoading = false;
  final List<String> moods = ["🥗 ヘルシー", "🍖 ガッツリ", "⏱️ 時短"];

  String _cat = "肉類", _name = "鶏むね肉", _unit = "g";
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  double _count = 1.0;
  bool _isFav = false;

  final List<String> units = ["個", "g", "kg", "ml", "L", "本", "枚", "パック", "合", "袋", "玉", "切れ", "丁", "缶", "尾"];
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
  }

  void _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(p.getString('inv') ?? "[]");
      shoppingList = jsonDecode(p.getString('shop') ?? "[]");
      modeIndex = p.getInt('mode') ?? 0;
      customColor = Color(p.getInt('color') ?? 0xFF1B5E20);
      _apiKey = p.getString('apiKey') ?? "";
    });
  }

  void _speak(String t) => js.context.callMethod('eval', [
        "window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"
      ]);

  String _getIcon(String n) {
    for (var c in foodMaster.values) {
      for (var i in c) { if (i["name"] == n) return i["icon"]; }
    }
    return "📦";
  }

  void _updateFoodSelection(String foodName) {
    final masterData = foodMaster[_cat]!.firstWhere((element) => element["name"] == foodName);
    setState(() {
      _name = foodName;
      _unit = masterData["unit"] ?? "個"; 
      _date = DateTime.now().add(Duration(days: masterData["limit"]));
    });
  }

  // 買い物リストから在庫へ戻す
  void _restockFromShop(int index) {
    setState(() {
      final item = shoppingList[index];
      Map<String, dynamic>? master;
      for(var list in foodMaster.values) {
        for(var m in list) { if(m["name"] == item["name"]) master = m; }
      }

      final double restockAmount = (master?["unit"] == "g" || master?["unit"] == "ml") ? 500.0 : 1.0;
      final String newExpiry = DateTime.now().add(Duration(days: master?["limit"] ?? 3)).toIso8601String();

      int existingIdx = inventory.indexWhere((i) => i["name"] == item["name"]);
      if (existingIdx != -1) {
        inventory[existingIdx]["count"] += restockAmount;
        inventory[existingIdx]["expiry"] = newExpiry;
      } else {
        inventory.add({
          "name": item["name"], "icon": item["icon"], "expiry": newExpiry,
          "count": restockAmount, "unit": master?["unit"] ?? "個",
          "step": (master?["unit"] == "g" || master?["unit"] == "ml") ? 50.0 : 1.0,
        });
      }
      _speak("${item["name"]}を補充したぞ！");
      shoppingList.removeAt(index);
      _save();
    });
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
        unselectedItemColor: Colors.white60,
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

  Widget _buildInv(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: inventory.length,
      itemBuilder: (context, i) {
        final item = inventory[i];
        final DateTime expiryDate = DateTime.parse(item["expiry"]);
        final bool isUrgent = expiryDate.difference(DateTime.now()).inDays <= 1;

        return Card(
          color: isUrgent ? Colors.redAccent.withOpacity(0.9) : Colors.black45,
          child: ListTile(
            leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
            title: Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(isUrgent ? "⚠️ 期限間近！" : "期限: ${item["expiry"].split('T')[0]}", style: const TextStyle(color: Colors.white70)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white), onPressed: () => setState(() {
                item["count"] = (item["count"] as double) - (item["step"] ?? 1.0);
                if (item["count"] <= 0) {
                  shoppingList.add({"name": item["name"], "icon": item["icon"]});
                  inventory.removeAt(i);
                  _speak("${item['name']}を買い物リストに入れたぞ。");
                }
                _save();
              })),
              Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white), onPressed: () => setState(() {
                item["count"] = (item["count"] as double) + (item["step"] ?? 1.0);
                _save();
              })),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildReg(Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label("1. カテゴリー", textColor),
        _drop(foodMaster.keys.toList(), _cat, (v) => setState(() { _cat = v!; _updateFoodSelection(foodMaster[v]![0]["name"]); })),
        const SizedBox(height: 15),
        _label("2. 食材", textColor),
        InkWell(onTap: _showFoodSelector, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)), child: Row(children: [Text(_getIcon(_name), style: const TextStyle(fontSize: 24)), const SizedBox(width: 15), Text(_name, style: const TextStyle(color: Colors.white, fontSize: 18)), const Spacer(), const Icon(Icons.arrow_drop_down, color: Colors.white)]))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label("3. 単位", textColor), _drop(units, _unit, (v) => setState(() => _unit = v!))])),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label("4. 期限", textColor),
            InkWell(onTap: () async {
              var p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 1000)));
              if (p != null) setState(() => _date = p);
            }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text("${_date.year}/${_date.month}/${_date.day}", style: const TextStyle(color: Colors.white))))
          ])),
        ]),
        const SizedBox(height: 15),
        _label("5. 初期個数", textColor),
        Row(children: [
          Expanded(child: _drop(List.generate(20, (i) => (i + 1).toString()), _count.toInt().toString(), (v) => setState(() => _count = double.parse(v!)))),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white), onPressed: () => setState(() { if (_count > 1) _count--; })),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white), onPressed: () => setState(() => _count++)),
        ]),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: () {
            double step = (_unit == "g" || _unit == "ml" || _unit == "合") ? 50.0 : 1.0;
            setState(() { 
              inventory.add({"name": _name, "icon": _getIcon(_name), "expiry": _date.toIso8601String(), "count": _count, "unit": _unit, "step": step}); 
              _tabIdx = 0; 
            });
            _save();
          },
          child: const Text("冷蔵庫に保管する", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildShop(Color textColor) {
    if (shoppingList.isEmpty) return Center(child: Text("買うべきものはないぞ。", style: TextStyle(color: textColor, fontSize: 18)));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: shoppingList.length,
      itemBuilder: (context, i) {
        final item = shoppingList[i];
        return Card(
          color: Colors.white12,
          child: ListTile(
            leading: Text(item["icon"] ?? "🛒", style: const TextStyle(fontSize: 24)),
            title: Text(item["name"], style: const TextStyle(color: Colors.white)),
            subtitle: const Text("チェックで在庫に補充するぞ", style: TextStyle(color: Colors.white38, fontSize: 10)),
            trailing: IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 30),
              onPressed: () => _restockFromShop(i),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRec(Color textColor) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: ElevatedButton.icon(
        icon: _isAiLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.auto_awesome),
        label: Text(_isAiLoading ? "考え中じゃ..." : "レシピを提案してもらう"),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber, foregroundColor: Colors.black),
        onPressed: _isAiLoading ? null : _generateRecipe,
      )),
      Expanded(child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(child: Text(_aiResult.isEmpty ? "レシピはここに表示されるぞ。" : _aiResult, style: const TextStyle(color: Colors.white, fontSize: 16)))))
    ]);
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("APIキーを設定してください。")));
      return;
    }
    setState(() { _isAiLoading = true; _aiResult = ""; });
    final ingredients = inventory.map((e) => "${e['name']}(${e['count']}${e['unit']})").join(", ");
    final prompt = "あなたは${chars[modeIndex]['n']}です。${ingredients}を使って気分に合わせたレシピを1つ提案してください。";
    try {
      final response = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _aiResult = data['candidates'][0]['content']['parts'][0]['text']; });
      }
    } catch (e) {
      setState(() => _aiResult = "エラーが発生したわい。");
    } finally {
      setState(() => _isAiLoading = false);
    }
  }

  void _showApiKeySetting() {
    TextEditingController controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("🔑 Gemini API設定", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(filled: true, fillColor: Colors.black, hintText: "API Keyを貼り付け"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("キャンセル")),
            ElevatedButton(onPressed: () {
              setState(() => _apiKey = controller.text.trim());
              _save();
              Navigator.pop(ctx);
            }, child: const Text("保存")),
          ],
        ),
      ),
    );
  }

  Widget _label(String t, Color c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold)));

  Widget _drop(List<String> items, String val, ValueChanged<String?> onC) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
    child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white))
  );

  void _showFoodSelector() {
    var foodList = foodMaster[_cat] ?? [];
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: foodList.length, itemBuilder: (context, i) => ListTile(leading: Text(foodList[i]["icon"]), title: Text(foodList[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { _updateFoodSelection(foodList[i]["name"]); Navigator.pop(ctx); })));
  }

  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("設定"), content: Column(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => ListTile(leading: Text(chars[i]["i"]), title: Text(chars[i]["n"]), onTap: () { setState(() => modeIndex = i); Navigator.pop(ctx); })))));
  }
}