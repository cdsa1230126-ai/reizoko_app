// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:js' as js;
import 'food_data.dart';
import 'package:http/http.dart' as http; // 追加：API通信用

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
  int _tabIdx = 1; // 最初は登録画面を表示
  int modeIndex = 0;
  List<dynamic> inventory = [], shoppingList = [];
  Color customColor = const Color(0xFF1B5E20);
  String _apiKey = "";

  // 追加：AIレシピ用ステート
  String _aiMood = "🥗 ヘルシー";
  String _aiResult = "";
  bool _isAiLoading = false;
  final List<String> moods = ["🥗 ヘルシー", "🍖 ガッツリ", "⏱️ 時短"];

  // 登録用ステート
  String _cat = "肉類", _name = "鶏むね肉", _unit = "個", _vUnit = "ml";
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  double _count = 1.0, _vol = 500.0;
  bool _isFav = false;

  final List<String> units = ["個", "g", "kg", "ml", "本", "枚", "パック", "合"];
  final List<Map<String, dynamic>> chars = [
    {"n": "長老", "i": "🧓", "m": "フォッフォッフォ、良い食材じゃ。"},
    {"n": "博士", "i": "🧑‍⚕️", "m": "フム、実に興味深いデータだ。"},
    {"n": "商人", "i": "🕶️", "m": "まいど！活きのいいのが入ったね！"},
  ];

  @override
  void initState() { super.initState(); _load(); }

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

  void _speak(String t) => js.context.callMethod('eval', ["window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"]);

  String _getIcon(String n) {
    for (var c in foodMaster.values) { for (var i in c) { if (i["name"] == n) return i["icon"]; } }
    return "📦";
  }

  // --- 追加：Gemini API連携関数 ---
  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty || inventory.isEmpty) return;
    setState(() { _isAiLoading = true; _aiResult = ""; });

    final ingredients = inventory.map((e) => "${e['name']}(${e['count']}${e['unit']})").join(", ");
    final charName = chars[modeIndex]["n"];
    final prompt = "あなたは$charNameです。冷蔵庫にある「$ingredients」を使って、気分が「$_aiMood」にぴったりの料理レシピを1つ提案してください。$charNameらしい口調で、材料と手順を簡潔に教えてください。";

    try {
      final response = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _aiResult = data['candidates'][0]['content']['parts'][0]['text']; });
        _speak("レシピが完成したぞ。");
      } else {
        setState(() { _aiResult = "通信エラーじゃ。APIキーを確認しておくれ。"; });
      }
    } catch (e) {
      setState(() { _aiResult = "エラーが発生したわい。接続を確認してな。"; });
    } finally {
      setState(() { _isAiLoading = false; });
    }
  }

  // --- 【おもてなし】APIキー設定ダイアログ ---
  void _showApiKeySetting() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text("安心・簡単 AI設定", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: const Column(
                  children: [
                    _InfoRow(Icons.check_circle, "料金はかかりません（無料）"),
                    SizedBox(height: 8),
                    _InfoRow(Icons.lock, "キーはあなたの端末内だけで守られます"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text("🔑 3ステップで完了！", style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _stepTile("1", "下のボタンで発行サイトを開く"),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => js.context.callMethod('open', ['https://aistudio.google.com/app/apikey']),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("発行サイト（Google）へ"),
                ),
              ),
              const SizedBox(height: 15),
              _stepTile("2", "「Create API key」を押してコピー"),
              _stepTile("3", "下の欄に貼り付けて保存する"),
              const SizedBox(height: 15),
              TextField(
                controller: TextEditingController(text: _apiKey),
                onChanged: (v) => _apiKey = v.trim(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black,
                  hintText: "ここに貼り付け（ペースト）",
                  hintStyle: const TextStyle(color: Colors.white24),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("後でやる")),
          ElevatedButton(
            onPressed: () { 
              _save(); 
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI設定を保存しました！")));
              _speak("これで準備万端じゃ！どんなレシピが良いか聞いておくれ。");
            },
            child: const Text("設定を保存して完了！"),
          ),
        ],
      ),
    );
  }

  // --- 【スクロール選択】食材セレクター ---
  void _showFoodSelector() {
    var foodList = foodMaster[_cat] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("$_cat を選んでください", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: foodList.length,
              itemBuilder: (context, index) {
                final f = foodList[index];
                return ListTile(
                  leading: Text(f["icon"], style: const TextStyle(fontSize: 24)),
                  title: Text(f["name"], style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      _name = f["name"];
                      _date = DateTime.now().add(Duration(days: f["limit"]));
                    });
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
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
          IconButton(icon: const Icon(Icons.vpn_key, color: Colors.amber), onPressed: _showApiKeySetting),
          IconButton(icon: Icon(Icons.palette, color: textColor), onPressed: _showSettings),
        ],
      ),
      body: [_buildInv(textColor), _buildReg(textColor), _buildShop(textColor), _buildRec(textColor)][_tabIdx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx, onTap: (i) => setState(() => _tabIdx = i),
        backgroundColor: Colors.black, selectedItemColor: Colors.yellowAccent, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "登録"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: "AIレシピ"),
        ],
      ),
    );
  }

  // --- 各タブのビルド ---
  Widget _buildReg(Color textColor) {
    return SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label("1. カテゴリー", textColor), 
      _drop(foodMaster.keys.toList(), _cat, (v) => setState(() { _cat = v!; _name = foodMaster[v]![0]["name"]; _date = DateTime.now().add(Duration(days: foodMaster[v]![0]["limit"])); })),
      const SizedBox(height: 20),
      _label("2. 食材 (タップして選択)", textColor),
      InkWell(
        onTap: _showFoodSelector,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
          child: Row(
            children: [
              Text(_getIcon(_name), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 15),
              Text(_name, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: Colors.white70),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label("3. 単位", textColor), _drop(units, _unit, (v) => setState(() => _unit = v!))])),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label("4. 期限", textColor), InkWell(onTap: () async { var p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730))); if (p != null) setState(() => _date = p); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text("${_date.year}/${_date.month}/${_date.day}", style: TextStyle(color: textColor))))])),
      ]),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_label("5. 個数", textColor), Row(children: [Text("★ お気に入り", style: TextStyle(color: textColor, fontSize: 12)), Switch(value: _isFav, activeColor: Colors.yellowAccent, onChanged: (v) => setState(() => _isFav = v))])]),
      Row(children: [
        Expanded(child: _drop(List.generate(20, (i) => (i+1).toString()), _count.toInt().toString(), (v) => setState(() => _count = double.parse(v!)))),
        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white70), onPressed: () => setState(() { if(_count > 1) _count--; })),
        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: () => setState(() => _count++)),
      ]),
      if (_cat == "飲み物") ...[const SizedBox(height: 20), _label("🥤 容量設定", textColor), Row(children: [Expanded(child: TextField(keyboardType: TextInputType.number, style: TextStyle(color: textColor), decoration: const InputDecoration(filled: true, fillColor: Colors.black26, hintText: "500"), onChanged: (v) => _vol = double.tryParse(v) ?? 500)), const SizedBox(width: 10), Expanded(child: _drop(["ml", "L"], _vUnit, (v) => setState(() => _vUnit = v!)))])],
      const SizedBox(height: 35),
      ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.yellowAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () {
          double step = (_name.contains("米") || _unit == "kg" || _unit == "合") ? 0.15 : 1.0;
          setState(() {
            inventory.add({
              "name": _name, "icon": _getIcon(_name), "expiry": _date.toIso8601String(),
              "count": _count, "unit": _unit, "step": step, "isFavorite": _isFav,
              "vol": _cat == "飲み物" ? _vol : null, "vUnit": _cat == "飲み物" ? _vUnit : null,
            });
            _tabIdx = 0;
          });
          _speak("${chars[modeIndex]["m"]} $_nameを入れたぞ。"); _save();
        },
        child: const Text("冷蔵庫に保管する", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    ]));
  }

  Widget _buildInv(Color textColor) {
    if (inventory.isEmpty) return Center(child: Text(chars[modeIndex]["m"], style: TextStyle(color: textColor)));
    return ListView.builder(
      itemCount: inventory.length, padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        final item = inventory[i];
        final days = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays + 1;
        bool isF = item["isFavorite"] ?? false;
        return Card(
          color: days <= 0 ? Colors.redAccent.withOpacity(0.4) : Colors.black45,
          child: ListTile(
            leading: InkWell(onTap: () { setState(() => inventory[i]["isFavorite"] = !isF); _save(); }, child: Stack(alignment: Alignment.bottomRight, children: [Text(item["icon"], style: const TextStyle(fontSize: 30)), Icon(isF ? Icons.star : Icons.star_border, color: Colors.yellowAccent, size: 18)])),
            title: Text("${item["name"]} × ${item["count"]} ${item["unit"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            subtitle: Text(days <= 0 ? "⚠️ 期限切れ！" : "あと $days 日", style: TextStyle(color: textColor.withOpacity(0.7))),
            trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.orangeAccent), onPressed: () {
              setState(() {
                if (item["count"] > item["step"]) { item["count"] -= item["step"]; } 
                else {
                  int sIdx = shoppingList.indexWhere((e) => e["name"] == item["name"]);
                  if (sIdx != -1) { shoppingList[sIdx]["count"] += 1.0; } else { shoppingList.add(Map.from(item)..["count"] = 1.0); }
                  inventory.removeAt(i);
                }
              }); _save();
            }),
          ),
        );
      },
    );
  }

  Widget _buildShop(Color textColor) {
    if (shoppingList.isEmpty) return Center(child: Text("買い物リストは空じゃ。", style: TextStyle(color: textColor)));
    shoppingList.sort((a, b) => ((a["isFavorite"] ?? false) ? 0 : 1).compareTo((b["isFavorite"] ?? false) ? 0 : 1));
    return ListView.builder(
      itemCount: shoppingList.length, padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) {
        final item = shoppingList[i];
        return Card(
          color: Colors.white10,
          child: ListTile(
            leading: Text(item["icon"], style: const TextStyle(fontSize: 25)),
            title: Text("${(item["isFavorite"] ?? false) ? '★ ' : ''}${item["name"]} (×${item["count"]})", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () { setState(() => shoppingList.removeAt(i)); _save(); }),
              IconButton(icon: const Icon(Icons.add_shopping_cart, color: Colors.cyanAccent), onPressed: () { setState(() { item["expiry"] = DateTime.now().add(const Duration(days: 3)).toIso8601String(); inventory.add(Map.from(item)); shoppingList.removeAt(i); }); _save(); }),
            ]),
          ),
        );
      },
    );
  }

  // --- 修正：AIレシピタブ ---
  Widget _buildRec(Color textColor) {
    if (_apiKey.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 64),
          const SizedBox(height: 16),
          const Text("AIレシピ機能が未設定です", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _showApiKeySetting, child: const Text("APIキーを設定する")),
        ]),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              Text("今の気分を選んでおくれ", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: moods.map((m) => ChoiceChip(
                  label: Text(m),
                  selected: _aiMood == m,
                  onSelected: (v) => setState(() => _aiMood = m),
                  selectedColor: Colors.yellowAccent,
                  labelStyle: TextStyle(color: _aiMood == m ? Colors.black : Colors.white),
                )).toList(),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text("${chars[modeIndex]["n"]}にレシピを聞く"),
                onPressed: (inventory.isEmpty || _isAiLoading) ? null : _generateRecipe,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _isAiLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.yellowAccent))
              : Text(_aiResult.isEmpty ? "${chars[modeIndex]["n"]}がレシピを考え中じゃ..." : _aiResult, 
                  style: TextStyle(color: textColor, fontSize: 16, height: 1.5)),
          ),
        ),
      ],
    );
  }

  // --- 共通パーツ ---
  Widget _label(String t, Color c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)));
  Widget _drop(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onC, isExpanded: true, underline: const SizedBox(), dropdownColor: Colors.black87, style: const TextStyle(color: Colors.white)));

  void _showSettings() {
    final colors = [Colors.black, const Color(0xFF263238), const Color(0xFF3E2723), const Color(0xFF1A237E), const Color(0xFF004D40), const Color(0xFF311B92), const Color(0xFF1B5E20), const Color(0xFF0D47A1), const Color(0xFF827717), const Color(0xFFBF360C), const Color(0xFF4E342E), const Color(0xFF424242), const Color(0xFFFFCDD2), const Color(0xFFF8BBD0), const Color(0xFFE1BEE7), const Color(0xFFD1C4E9), const Color(0xFFC5CAE9), const Color(0xFFB3E5FC), const Color(0xFFB2DFDB), const Color(0xFFDCEDC8), const Color(0xFFFFF9C4), const Color(0xFFFFECB3), const Color(0xFFFFE0B2), const Color(0xFFFFCCBC)];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900], title: const Text("アプリ設定", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(3, (i) => RadioListTile(title: Text("${chars[i]["i"]} ${chars[i]["n"]}", style: const TextStyle(color: Colors.white)), value: i, groupValue: modeIndex, onChanged: (v) { setState(() => modeIndex = v!); _save(); Navigator.pop(ctx); })),
        const Divider(color: Colors.white24),
        Wrap(spacing: 8, runSpacing: 8, children: colors.map((c) => InkWell(onTap: () { setState(() => customColor = c); _save(); Navigator.pop(ctx); }, child: Container(width: 35, height: 35, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white38))))).toList()),
        const SizedBox(height: 15),
        ElevatedButton(child: const Text("自由な色を選ぶ"), onPressed: () async { 
          final res = await js.context.callMethod('eval', ["new Promise((r) => { const i = document.createElement('input'); i.type = 'color'; i.onchange = () => r(i.value); i.click(); });"]);
          if (res != null) { setState(() => customColor = Color(int.parse("FF${res.toString().replaceFirst('#', '')}", radix: 16))); _save(); Navigator.pop(ctx); }
        })
      ])),
    ));
  }
}

// --- おもてなしダイアログ用のパーツ ---
Widget _stepTile(String num, String text) => Row(
  children: [
    CircleAvatar(radius: 12, backgroundColor: Colors.yellowAccent, child: Text(num, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
  ],
);

class _InfoRow extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: Colors.cyanAccent, size: 16), const SizedBox(width: 8), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))]);
}