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

  // --- レシート読み取りシミュレーション ---
  void _processReceipt() {
    setState(() {
      final items = [
        {"name": "たまご", "icon": "🥚", "count": 1.0, "unit": "パック", "limit": 7},
        {"name": "牛乳", "icon": "🥛", "count": 1.0, "unit": "本", "limit": 5},
        {"name": "納豆", "icon": "🥢", "count": 1.0, "unit": "パック", "limit": 10},
      ];
      for (var item in items) {
        inventory.add({
          "name": item["name"],
          "icon": item["icon"],
          "expiry": DateTime.now().add(Duration(days: item["limit"] as int)).toIso8601String(),
          "count": item["count"],
          "unit": item["unit"],
          "isFavorite": false,
        });
      }
      _tabIdx = 0;
      _speak("レシートから3つの食材を登録したぞ。");
      _save();
    });
  }

  // --- 買い物リストへの直接登録ダイアログ ---
  void _showShopAddDialog() {
    String tempName = "キャベツ";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("買い物リストに追加", style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "食材名を入力", hintStyle: TextStyle(color: Colors.white30)),
          onChanged: (v) => tempName = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("キャンセル")),
          ElevatedButton(onPressed: () {
            setState(() {
              shoppingList.add({"name": tempName, "icon": _getIcon(tempName), "count": 1.0, "unit": "個"});
              _save();
            });
            Navigator.pop(ctx);
          }, child: const Text("追加")),
        ],
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
          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.cyanAccent), onPressed: _startCameraScan),
          IconButton(icon: const Icon(Icons.palette, color: Colors.white), onPressed: _showSettings),
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
      floatingActionButton: _tabIdx == 2 ? FloatingActionButton(
        backgroundColor: Colors.yellowAccent,
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: _showShopAddDialog,
      ) : null,
    );
  }

  // --- カメラ起動ロジック (レシート/食材 選択式) ---
  Future<void> _startCameraScan() async {
    if (_cameras.isEmpty) return;

    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.fastfood, color: Colors.white), title: const Text("食材をスキャン", style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, "food")),
        ListTile(leading: const Icon(Icons.receipt_long, color: Colors.white), title: const Text("レシートを読み取り", style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, "receipt")),
      ])
    );

    if (type == null) return;

    _cameraController = CameraController(_cameras[0], ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(type == "food" ? "食材スキャン" : "レシート読み取り", style: const TextStyle(color: Colors.white)),
        content: SizedBox(width: 300, height: 300, child: CameraPreview(_cameraController!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("キャンセル")),
          ElevatedButton(onPressed: () {
            if (type == "food") {
              setState(() { _cat = "乳製品・大豆製品"; _name = "牛乳"; _unit = "ml"; _tabIdx = 1; });
              _speak("牛乳を認識したぞ。");
            } else {
              _processReceipt();
            }
            Navigator.pop(ctx);
          }, child: const Text("実行")),
        ],
      ),
    );

    await _cameraController?.dispose();
    _cameraController = null;
  }

  // --- 在庫グリッド ---
  Widget _buildInvGrid(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text("冷蔵庫は空っぽじゃ。", style: TextStyle(color: textColor, fontSize: 18)));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemCount: inventory.length,
      itemBuilder: (context, i) {
        final item = inventory[i];
        final expColor = _getExpiryColor(item["expiry"]);
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
                item["count"]--;
                if (item["count"] <= 0) {
                  shoppingList.add({ ...item, "count": 1.0 });
                  inventory.removeAt(i);
                  _speak("${item["name"]}が切れたぞ。");
                }
                _save();
              })),
              Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Colors.white)),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => setState(() { item["count"]++; _save(); })),
            ])
          ]),
        );
      },
    );
  }

  // --- 登録タブ (UI完全維持) ---
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
      _drop(List.generate(30, (i) => (i + 1).toString()), _count.toInt().toString(), (v) => setState(() => _count = double.parse(v!))),
      const SizedBox(height: 15),
      _stepTile("6", "お気に入り登録", textColor),
      Row(children: [
        const Text("⭐ お気に入り", style: TextStyle(color: Colors.white70)),
        const Spacer(),
        Switch(value: _isFav, activeColor: Colors.yellowAccent, onChanged: (v) => setState(() => _isFav = v)),
      ]),
      const SizedBox(height: 30),
      ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.yellowAccent),
        onPressed: () {
          setState(() { inventory.add({ "name": _name, "icon": _getIcon(_name), "expiry": _date.toIso8601String(), "count": _count, "unit": _unit, "isFavorite": _isFav }); _tabIdx = 0; });
          _speak("${chars[modeIndex]["m"]} $_nameを入れたぞ。");
          _save();
        },
        child: const Text("保管する", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    ]));
  }

  // --- 買い物タブ (＋ボタン追加) ---
  Widget _buildShop(Color textColor) {
    if (shoppingList.isEmpty) return Center(child: Text("買うべきものはないぞ。", style: TextStyle(color: textColor, fontSize: 18)));
    return ListView.builder(itemCount: shoppingList.length, itemBuilder: (context, i) {
      final item = shoppingList[i];
      return Card(color: Colors.white12, child: ListTile(
        leading: Text(item["icon"] ?? "🛒", style: const TextStyle(fontSize: 24)),
        title: Text(item["name"], style: const TextStyle(color: Colors.white)),
        trailing: IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent), onPressed: () {
          setState(() {
            inventory.add({ ...item, "expiry": DateTime.now().add(const Duration(days: 3)).toIso8601String() });
            shoppingList.removeAt(i);
            _save();
          });
        }),
      ));
    });
  }

  // --- AIレシピタブ (ムード維持) ---
  Widget _buildRec(Color textColor) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) {
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _aiMood == m ? Colors.yellowAccent : Colors.white10), onPressed: () => setState(() => _aiMood = m), child: Text(m, style: const TextStyle(fontSize: 10)))));
        }).toList()),
        const SizedBox(height: 10),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.amber), onPressed: _generateRecipe, child: Text(_isAiLoading ? "考え中じゃ..." : "AIレシピを提案", style: const TextStyle(color: Colors.black))),
      ])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(15), child: Text(_aiResult, style: const TextStyle(color: Colors.white))))
    ]);
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) return;
    setState(() { _isAiLoading = true; _aiResult = ""; });
    final ingredients = inventory.map((e) => e['name']).join(", ");
    final prompt = "あなたは${chars[modeIndex]["n"]}です。$ingredientsを使って気分が$_aiMoodになるレシピを教えて。";
    try {
      final res = await http.post(Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$_apiKey"), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));
      if (res.statusCode == 200) setState(() => _aiResult = jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text']);
    } catch (e) { setState(() => _aiResult = "エラーが発生したわい。"); }
    setState(() => _isAiLoading = false);
  }

  void _showFoodSelector() {
    var foodList = foodMaster[_cat] ?? [];
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: foodList.length, itemBuilder: (context, i) => ListTile(leading: Text(foodList[i]["icon"]), title: Text(foodList[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { setState(() => _name = foodList[i]["name"]); Navigator.pop(ctx); })));
  }

  void _showSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("設定"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(3, (i) => ListTile(leading: Text(chars[i]["i"]), title: Text(chars[i]["n"]), onTap: () { setState(() => modeIndex = i); Navigator.pop(ctx); })),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Colors.green[900]!, Colors.blue[900]!, Colors.red[900]!].map((c) => InkWell(onTap: () { setState(() => customColor = c); _save(); Navigator.pop(ctx); }, child: Container(width: 30, height: 30, color: c))).toList())
    ])));
  }

  Widget _stepTile(String step, String text, Color textColor) => Row(children: [
    CircleAvatar(radius: 12, backgroundColor: Colors.yellowAccent, child: Text(step, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
    const SizedBox(width: 10),
    Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
  ]);

  Widget _drop(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onC, isExpanded: true, underline: Container(), dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white)));
}