// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameras = await availableCameras();
  } catch (e) {
    _cameras = [];
  }
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

  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
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

  Color _getExpiryColor(String dateStr) {
    final expiry = DateTime.parse(dateStr);
    final diff = expiry.difference(DateTime.now()).inDays;
    if (diff < 0) return Colors.purpleAccent; 
    if (diff <= 1) return Colors.redAccent;    
    if (diff <= 3) return Colors.orangeAccent; 
    return Colors.white24;
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
          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.cyanAccent), onPressed: _startCameraScan),
          IconButton(icon: const Icon(Icons.vpn_key, color: Colors.amber), onPressed: _showApiKeySetting),
          IconButton(icon: Icon(Icons.palette, color: textColor), onPressed: _showSettings),
        ],
      ),
      body: [
        _buildInvGrid(textColor), 
        _buildReg(textColor),     
        _buildShop(textColor),    
        _buildRec(textColor)      
      ][_tabIdx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx,
        onTap: (i) => setState(() => _tabIdx = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.yellowAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AIレシピ"),
        ],
      ),
    );
  }

  // --- 在庫タブ ---
  Widget _buildInvGrid(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemCount: inventory.length,
      itemBuilder: (context, i) {
        final item = inventory[i];
        final expColor = _getExpiryColor(item["expiry"]);
        final double step = (item["step"] ?? 1.0).toDouble();
        return Container(
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15), border: Border.all(color: expColor, width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (item["isFavorite"] == true) const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.star, color: Colors.yellowAccent, size: 16))),
            Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 5),
            Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("期限: ${item["expiry"].split('T')[0]}", style: TextStyle(color: expColor == Colors.white24 ? Colors.white60 : expColor, fontSize: 11)),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => setState(() {
                item["count"] = (item["count"] as double) - step;
                if (item["count"] <= 0) {
                  shoppingList.add({ ...item, "count": (item["unit"] == "g" || item["unit"] == "ml") ? 500.0 : 1.0 });
                  inventory.removeAt(i);
                  _speak("${item["name"]}が切れたぞ。");
                }
                _save();
              })),
              Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white)),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => setState(() { item["count"] = (item["count"] as double) + step; _save(); })),
            ])
          ]),
        );
      },
    );
  }

  // --- 登録タブ (案B：冷蔵庫 or 買い物 振り分け) ---
  Widget _buildReg(Color textColor) {
    return SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        _stepTile("7", "容量設定", textColor),
        Row(children: [
          Expanded(child: TextField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "容量", labelStyle: TextStyle(color: Colors.white70), filled: true, fillColor: Colors.black26), keyboardType: TextInputType.number, onChanged: (v) => _vol = double.tryParse(v) ?? 500)),
          const SizedBox(width: 10),
          Expanded(child: _drop(["ml", "L"], _vUnit, (v) => setState(() => _vUnit = v!))),
        ]),
      ],
      const SizedBox(height: 30),
      // 振り分けボタン
      Row(children: [
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60), backgroundColor: Colors.white12),
          onPressed: () {
            double step = (_unit == "g" || _unit == "ml") ? 50.0 : (_unit == "合" ? 0.5 : 1.0);
            setState(() { shoppingList.add({ "name": _name, "icon": _getIcon(_name), "count": _count, "unit": _unit, "step": step }); _tabIdx = 2; });
            _speak("${_name}を買い物リストに入れたぞ。");
            _save();
          },
          child: const Text("🛒 買い物へ", style: TextStyle(color: Colors.white)),
        )),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60), backgroundColor: Colors.yellowAccent),
          onPressed: () {
            double step = (_unit == "g" || _unit == "ml") ? 50.0 : (_unit == "合" ? 0.5 : 1.0);
            setState(() { inventory.add({ "name": _name, "icon": _getIcon(_name), "expiry": _date.toIso8601String(), "count": _count, "unit": _unit, "step": step, "isFavorite": _isFav, "vol": _vol, "vUnit": _vUnit }); _tabIdx = 0; });
            _speak("${chars[modeIndex]["m"]} $_nameを入れたぞ。");
            _save();
          },
          child: const Text("🧊 冷蔵庫へ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        )),
      ]),
    ]));
  }

  // --- 買い物タブ ---
  Widget _buildShop(Color textColor) {
    if (shoppingList.isEmpty) return Center(child: Text("買うべきものはないぞ。", style: TextStyle(color: textColor, fontSize: 18)));
    return ListView.builder(padding: const EdgeInsets.all(10), itemCount: shoppingList.length, itemBuilder: (context, i) {
      final item = shoppingList[i];
      return Card(color: Colors.white12, child: ListTile(
        leading: Text(item["icon"] ?? "🛒", style: const TextStyle(fontSize: 24)),
        title: Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text("数量: ${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white38)),
        trailing: IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 30), onPressed: () {
          setState(() {
            inventory.add({ ...item, "expiry": DateTime.now().add(const Duration(days: 3)).toIso8601String(), "isFavorite": false });
            shoppingList.removeAt(i);
            _save();
          });
        }),
      ));
    });
  }

  // --- AIレシピタブ ---
  Widget _buildRec(Color textColor) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) {
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _aiMood == m ? Colors.yellowAccent : Colors.white10), onPressed: () => setState(() => _aiMood = m), child: Text(m, style: const TextStyle(fontSize: 10)))));
        }).toList()),
        const SizedBox(height: 10),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber), onPressed: _generateRecipe, child: Text(_isAiLoading ? "考え中じゃ..." : "AIレシピを提案", style: const TextStyle(color: Colors.black))),
      ])),
      Expanded(child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: SingleChildScrollView(child: Text(_aiResult.isEmpty ? "ここにレシピが出るぞ。" : _aiResult, style: const TextStyle(color: Colors.white))))),
    ]);
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) { _showApiKeySetting(); return; }
    setState(() { _isAiLoading = true; _aiResult = ""; });
    final ingredients = inventory.map((e) => e['name']).join(", ");
    final prompt = "あなたは${chars[modeIndex]["n"]}です。$ingredientsを使って気分が$_aiMoodになるレシピを1つ提案してください。";
    try {
      final res = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));
      if (res.statusCode == 200) setState(() => _aiResult = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text']);
    } catch (e) { setState(() => _aiResult = "エラーが発生したわい。"); }
    setState(() => _isAiLoading = false);
  }

  // --- 設定 (背景色・キャラ・APIキー) ---
  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("設定", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(3, (i) => ListTile(leading: Text(chars[i]["i"]), title: Text(chars[i]["n"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() => modeIndex = i); _save(); Navigator.pop(ctx); })),
        const Divider(color: Colors.white24),
        const Text("テーマカラー", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _colorDot(const Color(0xFF1B5E20)),
          _colorDot(const Color(0xFF0D47A1)),
          _colorDot(const Color(0xFFB71C1C)),
          _colorDot(const Color(0xFF4A148C)),
        ]),
      ]),
    ));
  }

  Widget _colorDot(Color c) => InkWell(onTap: () { setState(() => customColor = c); _save(); Navigator.pop(context); }, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white))));

  void _showApiKeySetting() {
    TextEditingController c = TextEditingController(text: _apiKey);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("API Key"), content: TextField(controller: c), actions: [ElevatedButton(onPressed: () { setState(() => _apiKey = c.text); _save(); Navigator.pop(ctx); }, child: const Text("保存"))]));
  }

  // --- カメラ機能 (完全遅延起動) ---
  Future<void> _startCameraScan() async {
    if (_cameras.isEmpty) return;
    _cameraController = CameraController(_cameras[0], ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    if (!mounted) return;
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black,
      content: SizedBox(width: 300, height: 300, child: CameraPreview(_cameraController!)),
      actions: [
        ElevatedButton(onPressed: () {
          // レシート読み取りシミュレーション
          setState(() {
            inventory.add({"name": "たまご", "icon": "🥚", "expiry": DateTime.now().add(const Duration(days: 7)).toIso8601String(), "count": 1.0, "unit": "パック", "isFavorite": false});
            _tabIdx = 0;
          });
          _speak("レシートを読み取ったぞ。");
          Navigator.pop(ctx);
        }, child: const Text("レシート読み取り")),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("閉じる"))
      ],
    ));
    await _cameraController?.dispose();
    _cameraController = null;
  }

  void _showFoodSelector() {
    var foodList = foodMaster[_cat] ?? [];
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: foodList.length, itemBuilder: (context, i) => ListTile(leading: Text(foodList[i]["icon"]), title: Text(foodList[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() { _name = foodList[i]["name"]; _date = DateTime.now().add(Duration(days: foodList[i]["limit"])); }); Navigator.pop(ctx); })));
  }

  Widget _stepTile(String step, String text, Color textColor) => Row(children: [
    CircleAvatar(radius: 12, backgroundColor: Colors.yellowAccent, child: Text(step, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
    const SizedBox(width: 10),
    Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
  ]);

  Widget _drop(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white)));
}