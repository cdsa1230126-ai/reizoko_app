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
  double _amt = 1.0;

  final List<Map<String, dynamic>> chars = [
    {"n": "長老", "i": "🧓", "t": "AI冷蔵庫番"},
    {"n": "博士", "i": "🧑‍⚕️", "t": "システム"},
    {"n": "商人", "i": "🕶️", "t": "激安市"},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('inv', jsonEncode(inventory));
    await p.setString('shop', jsonEncode(shoppingList));
    await p.setString('fav_recipes', jsonEncode(favoriteRecipes));
    await p.setInt('mode', modeIndex);
    await p.setInt('col', customColor.value);
    await p.setString('apiKey', _apiKey);
    await p.setBool('isListView', _isListView);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(p.getString('inv') ?? '[]');
      shoppingList = jsonDecode(p.getString('shop') ?? '[]');
      favoriteRecipes = jsonDecode(p.getString('fav_recipes') ?? '[]');
      modeIndex = p.getInt('mode') ?? 0;
      customColor = Color(p.getInt('col') ?? 0xFF004400);
      _apiKey = p.getString('apiKey') ?? "";
      _isListView = p.getBool('isListView') ?? true;
      _sortInventory();
    });
  }

  void _sortInventory() {
    inventory.sort((a, b) => (a['expiry'] ?? "9999-12-31").compareTo(b['expiry'] ?? "9999-12-31"));
  }

  void _speak(String t) => js.context.callMethod('eval', ["window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"]);

  // --- 食材追加ロジック (期限計算統合) ---
  void _addItem(bool isInv) {
    int limit = 3; // デフォルト
    // マスターデータから期限を取得
    for (var l in foodMaster.values) {
      for (var i in l) {
        if (i["name"] == _name) { limit = i["limit"]; break; }
      }
    }
    final now = DateTime.now();
    final expiry = now.add(Duration(days: limit));

    final item = {
      "name": _name,
      "cat": _cat,
      "amt": _amt,
      "unit": _unit,
      "loc": _loc,
      "date": DateFormat('yyyy-MM-dd').format(now),
      "expiry": DateFormat('yyyy-MM-dd').format(expiry),
    };

    setState(() {
      if (isInv) {
        inventory.add(item);
        _sortInventory();
        _speak("$_nameを追加した${chars[modeIndex]['s'] == '～じゃ' ? 'ぞい' : chars[modeIndex]['s'] == '～である' ? 'である' : chars[modeIndex]['s'] == '～ですよ！' ? 'ですよ！' : ''}。");
      } else {
        shoppingList.add(item);
      }
    });
    _save();
  }

  // --- 在庫消費ロジック (お米・液体計算統合) ---
  void _use(dynamic item, int index) {
    showDialog(
      context: context,
      builder: (ctx) {
        double useAmt = 1.0;
        bool isRice = item['name'].contains("米");
        bool isLiquid = ["ml", "L"].contains(item['unit']);
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("${item['name']}をどれくらい使う${chars[modeIndex]['s']}？", style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              if (isRice) const Text("※1合=0.15kgで計算します", style: TextStyle(color: Colors.amber, fontSize: 12)),
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: "数量 (${isRice ? '合 または ' : ''}${item['unit']})", labelStyle: const TextStyle(color: Colors.white70)),
                onChanged: (v) => useAmt = double.tryParse(v) ?? 0,
              ),
              if (isLiquid) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  ElevatedButton(onPressed: () => setS(() => useAmt = 15), child: const Text("大さじ")),
                  ElevatedButton(onPressed: () => setS(() => useAmt = 5), child: const Text("小さじ")),
                ]),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("キャンセル")),
              ElevatedButton(onPressed: () {
                setState(() {
                  double finalUse = isRice ? useAmt * 0.15 : useAmt;
                  if (item['unit'] == "L" && isLiquid && useAmt >= 1) finalUse = useAmt / 1000;
                  item['amt'] -= finalUse;
                  if (item['amt'] <= 0) {
                    // 買い物リストへ移動
                    _moveToShopping(item, index);
                  }
                });
                _save();
                Navigator.pop(ctx);
              }, child: const Text("確定")),
            ],
          );
        });
      },
    );
  }

  void _moveToShopping(dynamic item, int index) {
    setState(() {
      inventory.removeAt(index);
      shoppingList.add({...item, 'amt': 1.0}); // デフォルト1個で登録
      _speak("${item['name']}を買い物リストに移した${chars[modeIndex]['s']}。");
    });
  }

  void _buy(dynamic item, int index) {
    setState(() {
      shoppingList.removeAt(index);
      // 購入時は期限を3日後に設定して在庫へ
      item['expiry'] = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 3)));
      inventory.add(item);
      _sortInventory();
    });
    _save();
    _speak("${item['name']}を購入した${chars[modeIndex]['s']}！");
  }

  // --- AIレシピ生成 ---
  Future<void> _askAI() async {
    if (_apiKey.isEmpty) return;
    setState(() { _isAiLoading = true; _aiResult = ""; });
    final names = inventory.map((e) => e['name']).join(",");
    final charSuffix = chars[modeIndex]['s'] ?? '';
    final prompt = "在庫:$names を使い、$_aiMoodレシピを提案。回答は[料理名][材料][手順]で。語尾は$charSuffixで。";

    try {
      final res = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]})
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      setState(() { _aiResult = data['candidates'][0]['content']['parts'][0]['text']; });
    } catch (e) {
      setState(() { _aiResult = "通信エラーじゃ。"; });
    }
    setState(() { _isAiLoading = false; });
  }

  // --- UI構築 ---
  @override
  Widget build(BuildContext context) {
    final charNames = chars.map((e) => e['n']).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("${chars[modeIndex]['i']} ${chars[modeIndex]['t']}"),
        backgroundColor: customColor,
        actions: [
          IconButton(icon: Icon(_isListView ? Icons.grid_view : Icons.list), onPressed: () { setState(() => _isListView = !_isListView); _save(); }),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx,
        onTap: (i) => setState(() => _tabIdx = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white30,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "買い物"),
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "在庫"),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "レシピ"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "設定"),
        ],
      ),
      floatingActionButton: _tabIdx < 2 ? FloatingActionButton(backgroundColor: customColor, onPressed: _showAddDialog, child: const Icon(Icons.add)) : null,
    );
  }

  Widget _buildBody() {
    if (_tabIdx == 0) return _buildList(shoppingList, true);
    if (_tabIdx == 1) return Column(children: [
      Expanded(child: _buildList(inventory, false)),
      _buildAiSection(),
    ]);
    if (_tabIdx == 2) return _buildRecipeBook();
    return _buildSettings();
  }

  Widget _buildList(List<dynamic> list, bool isShop) {
    if (list.isEmpty) return const Center(child: Text("空っぽ", style: TextStyle(color: Colors.white30)));
    return _isListView 
      ? ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => _itemDismissible(list[i], i, isShop))
      : GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5), itemCount: list.length, itemBuilder: (ctx, i) => _itemDismissible(list[i], i, isShop));
  }

  // スワイプ機能の実装
  Widget _itemDismissible(dynamic item, int i, bool isShop) {
    return Dismissible(
      key: UniqueKey(), // 各アイテムに固有のキーを与える
      direction: DismissDirection.endToStart, // 右から左へのスワイプ
      background: Container(
        color: isShop ? Colors.green[800] : Colors.red[800],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(isShop ? Icons.check : Icons.local_fire_department, color: Colors.white),
      ),
      onDismissed: (dir) {
        // スワイプが完了した時の処理
        if (isShop) {
          _buy(item, i); // 購入
        } else {
          // 在庫の場合は、消費ダイアログを出すか、1個消費して買い物へ送るか
          setState(() {
            item['amt'] -= 1.0;
            if (item['amt'] <= 0) {
              _moveToShopping(item, i); // 買い物へ移動
            } else {
              // 1個減らして在庫に残す
              inventory[i] = item;
              _sortInventory();
              _save();
              _speak("${item['name']}を1個消費した${chars[modeIndex]['s']}。");
            }
          });
        }
      },
      confirmDismiss: (dir) async {
        // 在庫タブの場合のみ、特殊計算のためにダイアログを出すか
        if (!isShop && (item['name'].contains("米") || ["ml", "L"].contains(item['unit']))) {
          _use(item, i);
          return false; // スワイプをキャンセルしてダイアログを優先
        }
        return true; // 普通の食材ならスワイプを続行
      },
      child: _itemCard(item, i, isShop),
    );
  }

  Widget _itemCard(dynamic item, int i, bool isShop) {
    // 期限に応じた背景色変更
    Color cardCol = Colors.grey[900]!;
    if (!isShop) {
      final diff = DateTime.parse(item['expiry'] ?? "9999-12-31").difference(DateTime.now()).inDays;
      if (diff < 0) {
        cardCol = Colors.red.withOpacity(0.3); // 期限切れ
      } else if (diff <= 2) {
        cardCol = Colors.orange.withOpacity(0.3); // 2日以内
      }
    }

    return Card(
      color: isShop ? Colors.transparent : cardCol, // 買い物タブのCard背景を透過に
      elevation: isShop ? 0 : 2, // 買い物タブのエレベーションを0に
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Text(_getIcon(item['name']), style: const TextStyle(fontSize: 24)),
        title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("${item['amt']}${item['unit']} / ${item['loc'] ?? '冷蔵'}\n期限: ${item['expiry'] ?? '未設定'}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
        trailing: isShop ? 
          IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _buy(item, i)) :
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: () => _use(item, i)),
      ),
    );
  }

  Widget _buildAiSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.grey[900],
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: moods.map((m) => ChoiceChip(label: Text(m), selected: _aiMood == m, onSelected: (s) => setState(() => _aiMood = m))).toList()),
        const SizedBox(height: 10),
        if (_isAiLoading) const LinearProgressIndicator() else 
        ElevatedButton(onPressed: _askAI, style: ElevatedButton.styleFrom(backgroundColor: customColor), child: const Text("AIにレシピを聞く")),
        if (_aiResult.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: SingleChildScrollView(child: Text(_aiResult, style: const TextStyle(color: Colors.white, fontSize: 12))))
      ]),
    );
  }

  Widget _buildRecipeBook() {
    return favoriteRecipes.isEmpty ? const Center(child: Text("レシピはありません", style: TextStyle(color: Colors.white24))) :
      ListView.builder(itemCount: favoriteRecipes.length, itemBuilder: (ctx, i) => Card(
        color: Colors.grey[900],
        child: ExpansionTile(
          title: Text(favoriteRecipes[i]['title'], style: const TextStyle(color: Colors.white)),
          subtitle: Text(favoriteRecipes[i]['date']),
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(favoriteRecipes[i]['body'], style: const TextStyle(color: Colors.white))),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() { favoriteRecipes.removeAt(i); _save(); }))
          ],
        ),
      ));
  }

  Widget _buildSettings() {
    final charNames = chars.map((e) => e['n']).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _label("キャラクター"),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [0, 1, 2].map((i) => ElevatedButton(onPressed: () { setState(() => modeIndex = i); _save(); }, style: ElevatedButton.styleFrom(backgroundColor: modeIndex == i ? customColor : Colors.grey[800]), child: Text(charNames[i]))).toList()),
      const SizedBox(height: 20),
      _label("Gemini API Key"),
      TextField(controller: TextEditingController(text: _apiKey), decoration: const InputDecoration(filled: true, fillColor: Colors.white10), style: const TextStyle(color: Colors.white), onChanged: (v) => _apiKey = v),
      const SizedBox(height: 20),
      _label("テーマカラー"),
      Wrap(children: [Colors.green, Colors.blue, Colors.red, Colors.orange].map((c) => IconButton(icon: Icon(Icons.circle, color: c), onPressed: () { setState(() => customColor = c); _save(); })).toList()),
    ]);
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("食材追加", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dropdown(foodMaster.keys.toList(), _cat, (v) => setS(() => _cat = v!)),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: () {
          var list = foodMaster[_cat] ?? [];
          showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) => ListTile(title: Text(list[i]["name"], style: const TextStyle(color: Colors.white)), onTap: () { setS(() => _name = list[i]["name"]); Navigator.pop(ctx); })));
        }, child: Text(_name)),
        _dropdown(["個", "g", "kg", "ml", "L", "合", "束", "本"], _unit, (v) => setS(() => _unit = v!)),
        _dropdown(["冷蔵", "冷凍", "野菜室", "常温"], _loc, (v) => setS(() => _loc = v!)),
        TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "数量"), style: const TextStyle(color: Colors.white), onChanged: (v) => _amt = double.tryParse(v) ?? 1.0),
      ])),
      actions: [
        TextButton(onPressed: () { _addItem(false); Navigator.pop(ctx); }, child: const Text("買い物")),
        ElevatedButton(onPressed: () { _addItem(true); Navigator.pop(ctx); }, child: const Text("在庫追加")),
      ],
    )));
  }

  String _getIcon(String n) {
    for (var l in foodMaster.values) { for (var i in l) { if (i["name"] == n) return i["icon"]; } }
    return "📦";
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(s, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)));

  Widget _dropdown(List<String> items, String val, ValueChanged<String?> onC) => Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)), child: DropdownButton<String>(value: val, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(), onChanged: onC, dropdownColor: Colors.grey[900], isExpanded: true, underline: const SizedBox()));
}