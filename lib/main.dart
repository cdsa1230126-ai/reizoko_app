// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:js' as js;

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: ReizokoApp(), debugShowCheckedModeBanner: false));
}

class ReizokoApp extends StatefulWidget {
  const ReizokoApp({super.key});
  @override
  State<ReizokoApp> createState() => _ReizokoAppState();
}

class _ReizokoAppState extends State<ReizokoApp> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  int modeIndex = 0;
  List<dynamic> inventory = [];
  List<dynamic> shoppingList = [];
  List<dynamic> recipeList = [];
  String selectedIcon = "🥩";
  final List<String> icons = ["🥩", "🐟", "🥦", "🍎", "🥛", "📦"];

  Color customColor = const Color(0xFF1B5E20); 
  String? apiKey;

  CameraController? _cameraController;
  bool _isCameraInitializing = false;
  bool _isSuggesting = false;
  String? _capturedImagePath;

  // 入力用コントローラー
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(text: "3");
  final TextEditingController _countController = TextEditingController(text: "1"); // 個数用
  final TextEditingController _recipeTitleController = TextEditingController();
  final TextEditingController _recipeBodyController = TextEditingController();
  final TextEditingController _apiController = TextEditingController();

  late AnimationController _blinkController;

  final List<Map<String, dynamic>> colorList = [
    {"group": "モノトーン", "name": "ホワイト", "color": Color(0xFFFFFFFF)},
    {"group": "モノトーン", "name": "ブラック", "color": Color(0xFF000000)},
    {"group": "赤・桃", "name": "ピンク", "color": Color(0xFFFFC0CB)},
    {"group": "赤・桃", "name": "レッド", "color": Color(0xFFFF0000)},
    {"group": "青・紺", "name": "スカイブルー", "color": Color(0xFF87CEEB)},
    {"group": "緑", "name": "フォレストグリーン", "color": Color(0xFF228B22)},
    {"group": "黄・橙", "name": "オレンジ", "color": Color(0xFFFFA500)},
  ];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _loadData().then((_) => _checkUrgentItems());
  }

  Color _getTextColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  void _sortInventory() {
    inventory.sort((a, b) {
      String limitA = a["limit"].toString();
      String limitB = b["limit"].toString();
      if (limitA.contains("今日")) return -1;
      if (limitB.contains("今日")) return 1;
      int daysA = int.tryParse(RegExp(r'\d+').stringMatch(limitA) ?? "999") ?? 999;
      int daysB = int.tryParse(RegExp(r'\d+').stringMatch(limitB) ?? "999") ?? 999;
      return daysA.compareTo(daysB);
    });
  }

  // --- カメラ機能 ---
  Future<void> _initCamera() async {
    setState(() => _isCameraInitializing = true);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) { setState(() => _isCameraInitializing = false); return; }
      final back = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => _cameras[0]);
      _cameraController = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitializing = false);
    } catch (e) { setState(() => _isCameraInitializing = false); }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      setState(() { _cameraController = null; _isCameraInitializing = false; });
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      setState(() => _capturedImagePath = image.path);
    } catch (e) { debugPrint("撮影エラー: $e"); }
  }

  @override
  void dispose() {
    _cameraController?.dispose(); _nameController.dispose(); _dateController.dispose(); 
    _countController.dispose(); _recipeTitleController.dispose(); _recipeBodyController.dispose(); 
    _apiController.dispose(); _blinkController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> charSettings = [
    {"name": "🧓 長老", "flavor": "「魔物を倒して食卓を豊かにするのじゃ！」", "empty": "食材がないのう。", "gain": "を討伐！", "add": "魔物を写して登録するのじゃ！"},
    {"name": "🧑‍⚕️ ドクター", "flavor": "「食材の栄養を管理しましょう。」", "empty": "空の状態です。", "gain": "を補給！", "add": "栄養素をスキャンしてください。"},
    {"name": "🕶️ トレーダー", "flavor": "「資産の回転率を上げろ。」", "empty": "在庫ゼロだ。", "gain": "を決済！", "add": "新アセットを撮影しろ。"}
  ];

  void _speak(String text) {
    String safeText = text.replaceAll("'", "");
    js.context.callMethod('eval', ["""
      window.speechSynthesis.cancel();
      const uttr = new SpeechSynthesisUtterance('$safeText');
      uttr.lang = 'ja-JP';
      uttr.rate = 1.1;
      window.speechSynthesis.speak(uttr);
    """]);
  }

  // --- データの保存・読込 ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('modeIndex', modeIndex);
    await prefs.setString('inventory', jsonEncode(inventory));
    await prefs.setString('shoppingList', jsonEncode(shoppingList));
    await prefs.setString('recipeList', jsonEncode(recipeList));
    await prefs.setInt('savedColor', customColor.value);
    await prefs.setString('gemini_api_key', apiKey ?? "");
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      modeIndex = prefs.getInt('modeIndex') ?? 0;
      inventory = jsonDecode(prefs.getString('inventory') ?? "[]");
      shoppingList = jsonDecode(prefs.getString('shoppingList') ?? "[]");
      recipeList = jsonDecode(prefs.getString('recipeList') ?? "[]");
      int? colorVal = prefs.getInt('savedColor');
      if (colorVal != null) customColor = Color(colorVal);
      apiKey = prefs.getString('gemini_api_key');
      _apiController.text = apiKey ?? "";
    });
  }

  void _checkUrgentItems() {
    if (inventory.any((item) => item["limit"].toString().contains("今日") || item["limit"].toString().contains("あと1日"))) {
      Future.delayed(const Duration(seconds: 1), () => _speak("警告！期限が近い食材があります"));
    }
  }

  // --- AI相談 ---
  Future<void> _askGemini() async {
    if (apiKey == null || apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("設定からAIの準備をしてください")));
      return;
    }
    setState(() => _isSuggesting = true);
    await Future.delayed(const Duration(seconds: 2));
    _showRecipeResult("【${charSettings[modeIndex]['name']}の提案】\n今の食材なら「秘密の野菜炒め」が良さそうじゃ！期限の近い食材から使うのがコツじゃぞ。");
    setState(() => _isSuggesting = false);
  }

  void _showRecipeResult(String result) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("AIのレシピ提案"),
      content: Text(result),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("了解！"))],
    ));
  }

  // --- APIガイド ---
  void _showApiGuide() {
    int step = 1;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: Text("AIシェフ準備 ($step/3)"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (step == 1) ...[
            const Text("まずはGoogleのサイトで、AIを使うための『合言葉』を発行します。"),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: () => js.context.callMethod('open', ['https://aistudio.google.com/app/apikey']), child: const Text("サイトを開く")),
          ] else if (step == 2) ...[
            const Text("サイトの中にある青いボタン『Create API key』を押して、出てきた英数字をコピーしてください。"),
            const Icon(Icons.content_copy, size: 50, color: Colors.blue),
          ] else ...[
            const Text("最後に、下の欄にコピーした合言葉を貼り付けて完了です！"),
            TextField(controller: _apiController, decoration: const InputDecoration(hintText: "AIza..."), onChanged: (v) => apiKey = v),
          ]
        ]),
        actions: [
          if (step > 1) TextButton(onPressed: () => setDialogState(() => step--), child: const Text("戻る")),
          if (step < 3) ElevatedButton(onPressed: () => setDialogState(() => step++), child: const Text("次へ"))
          else ElevatedButton(onPressed: () { _saveData(); Navigator.pop(context); }, child: const Text("完了！")),
        ],
      );
    }));
  }

  // --- UIビルド: 冷蔵庫リスト ---
  Widget _buildInventoryView(Color textColor) {
    var char = charSettings[modeIndex];
    _sortInventory();
    return Column(children: [
      Container(padding: const EdgeInsets.all(15), width: double.infinity, color: textColor.withAlpha(20), child: Text("${char["name"]}\n${char["flavor"]}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
      Expanded(
        child: inventory.isEmpty 
          ? Center(child: Text(char["empty"], style: TextStyle(color: textColor.withAlpha(120))))
          : ListView.builder(
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                bool isUrgent = item["limit"].toString().contains("今日") || item["limit"].toString().contains("あと1日");
                return Dismissible(
                  key: UniqueKey(),
                  onDismissed: (dir) { setState(() { shoppingList.add(item); inventory.removeAt(index); }); _speak("${item["name"]}${char["gain"]}"); _saveData(); },
                  child: AnimatedBuilder(
                    animation: _blinkController,
                    builder: (context, child) => Card(
                      color: isUrgent ? Colors.redAccent.withAlpha((150 + (_blinkController.value * 105)).toInt()) : textColor.withAlpha(40),
                      elevation: 0,
                      child: ListTile(
                        leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 25)),
                        title: Row(
                          children: [
                            Text(item["name"], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            // ★ 個数表示を追加
                            Text("x ${item["count"] ?? 1}", style: TextStyle(color: textColor.withAlpha(180), fontSize: 14)),
                          ],
                        ),
                        trailing: Text(item["limit"], style: TextStyle(color: isUrgent ? Colors.white : Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    ]);
  }

  // --- UIビルド: 登録画面 ---
  Widget _buildAddView(Color textColor) {
    var char = charSettings[modeIndex];
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      Text("📷 ${char["add"]}", style: TextStyle(color: textColor, fontSize: 16)),
      const SizedBox(height: 15),
      Container(height: 250, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: textColor.withAlpha(100)), borderRadius: BorderRadius.circular(15)),
        child: ClipRRect(borderRadius: BorderRadius.circular(14),
          child: _capturedImagePath != null 
            ? Stack(fit: StackFit.expand, children: [Image.network(_capturedImagePath!, fit: BoxFit.cover), Positioned(right: 10, top: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => setState(() => _capturedImagePath = null))))])
            : (_cameraController != null && _cameraController!.value.isInitialized)
              ? Stack(alignment: Alignment.bottomCenter, children: [AspectRatio(aspectRatio: _cameraController!.value.aspectRatio, child: CameraPreview(_cameraController!)), Positioned(right: 10, top: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _stopCamera))), Padding(padding: const EdgeInsets.only(bottom: 10), child: FloatingActionButton(mini: true, backgroundColor: Colors.white.withAlpha(200), onPressed: _takePicture, child: const Icon(Icons.camera_alt, color: Colors.black)))])
              : Center(child: ElevatedButton.icon(onPressed: _initCamera, icon: const Icon(Icons.videocam), label: const Text("カメラ起動")))),
      ),
      const SizedBox(height: 20),
      Wrap(spacing: 10, children: icons.map((icon) => GestureDetector(onTap: () => setState(() => selectedIcon = icon), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: selectedIcon == icon ? Colors.yellowAccent : textColor.withAlpha(30), borderRadius: BorderRadius.circular(8)), child: Text(icon, style: const TextStyle(fontSize: 24))))).toList()),
      TextField(controller: _nameController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "食材名", labelStyle: TextStyle(color: textColor.withAlpha(150)))),
      TextField(controller: _dateController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "期限（数字）", labelStyle: TextStyle(color: textColor.withAlpha(150)))),
      // ★ 個数入力欄を追加
      TextField(controller: _countController, style: TextStyle(color: textColor), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "個数", labelStyle: TextStyle(color: textColor.withAlpha(150)))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { if (_nameController.text.isNotEmpty) { 
        _addItem(_nameController.text, _dateController.text, int.tryParse(_countController.text) ?? 1); 
        _nameController.clear(); 
        _countController.text = "1";
        _capturedImagePath = null; 
        setState(() => _currentTabIndex = 0); 
      } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, foregroundColor: Colors.black), child: const Text("登録！", style: TextStyle(fontWeight: FontWeight.bold))))
    ]));
  }

  // --- UIビルド: レシピ画面 ---
  Widget _buildRecipeView(Color textColor) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(15), width: double.infinity, color: textColor.withAlpha(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("📜 秘伝のレシピ帳", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        Row(children: [
          ElevatedButton.icon(onPressed: _isSuggesting ? null : _askGemini, icon: _isSuggesting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology, size: 18), label: const Text("AI相談"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black)),
          const SizedBox(width: 5),
          ElevatedButton.icon(onPressed: _showAddRecipeDialog, icon: const Icon(Icons.add, size: 18), label: const Text("登録"), style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, foregroundColor: Colors.black)),
        ])
      ])),
      Expanded(child: recipeList.isEmpty ? Center(child: Text("レシピはまだありません", style: TextStyle(color: textColor.withAlpha(120)))) : ListView.builder(itemCount: recipeList.length, itemBuilder: (context, index) { final recipe = recipeList[index]; return Card(color: textColor.withAlpha(30), elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ExpansionTile(title: Text(recipe["title"], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), children: [Padding(padding: const EdgeInsets.all(15), child: Align(alignment: Alignment.centerLeft, child: Text(recipe["body"], style: TextStyle(color: textColor)))), TextButton(onPressed: () { setState(() { recipeList.removeAt(index); }); _saveData(); }, child: const Text("削除", style: TextStyle(color: Colors.redAccent)))])); }))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _getTextColor(customColor);
    return Scaffold(
      backgroundColor: customColor,
      appBar: AppBar(title: Text(charSettings[modeIndex]["name"], style: TextStyle(color: textColor)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor), actions: [IconButton(onPressed: _showShoppingList, icon: const Icon(Icons.shopping_cart)), IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings))]),
      body: IndexedStack(index: _currentTabIndex, children: [_buildInventoryView(textColor), _buildAddView(textColor), _buildRecipeView(textColor)]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _currentTabIndex, onTap: (i) { if (i != 1) _stopCamera(); setState(() => _currentTabIndex = i); }, backgroundColor: Colors.black.withAlpha(200), selectedItemColor: Colors.yellowAccent, unselectedItemColor: Colors.white54, items: const [BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "冷蔵庫"), BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "登録"), BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "レシピ")]),
    );
  }

  void _showSettings() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("設定・デザイン"), content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("✨ AIシェフの準備", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      ElevatedButton(onPressed: _showApiGuide, child: const Text("準備ガイド（30秒）を開く")),
      const Divider(),
      const Text("モード切替", style: TextStyle(fontWeight: FontWeight.bold)),
      ...List.generate(3, (i) => RadioListTile(value: i, groupValue: modeIndex, title: Text(charSettings[i]["name"]), onChanged: (v) { setState(() => modeIndex = v!); _saveData(); Navigator.pop(context); })),
      const Divider(),
      const Text("カラー選択", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      SizedBox(height: 200, child: ListView.builder(itemCount: colorList.length, itemBuilder: (context, index) { final c = colorList[index]; return ListTile(leading: CircleAvatar(backgroundColor: c["color"], radius: 15), title: Text(c["name"]), onTap: () { setState(() => customColor = c["color"]); _saveData(); Navigator.pop(context); }); }))
    ])))));
  }

  // ★ アイテム追加ロジック (個数対応)
  void _addItem(String name, String date, int count) { 
    String formattedDate = date;
    if (RegExp(r'^\d+$').hasMatch(date)) { formattedDate = "あと${date}日"; }
    setState(() { 
      inventory.add({
        "name": name, 
        "icon": selectedIcon, 
        "limit": formattedDate,
        "count": count, // 個数を追加
      }); 
    }); 
    _saveData(); 
  }

  void _showAddRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("レシピを登録"), content: SingleChildScrollView(child: Column(children: [TextField(controller: _recipeTitleController, decoration: const InputDecoration(labelText: "料理名")), TextField(controller: _recipeBodyController, maxLines: 5, decoration: const InputDecoration(labelText: "材料・作り方"))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")), ElevatedButton(onPressed: () { if (_recipeTitleController.text.isNotEmpty) { setState(() { recipeList.add({"title": _recipeTitleController.text, "body": _recipeBodyController.text}); }); _saveData(); _recipeTitleController.clear(); _recipeBodyController.clear(); Navigator.pop(context); } }, child: const Text("登録"))]));
  }

  void _showShoppingList() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("🛒 お買い物メモ"), content: SizedBox(width: double.maxFinite, child: shoppingList.isEmpty ? const Text("空です") : ListView.builder(shrinkWrap: true, itemCount: shoppingList.length, itemBuilder: (context, i) => ListTile(leading: Text(shoppingList[i]["icon"] ?? "📦"), title: Text(shoppingList[i]["name"])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("閉じる"))]));
  }
}