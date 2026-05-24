// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:js' as js;
import 'dart:html' as html;
import 'food_data.dart';
import 'api_images.dart';
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
  DateTime? _lastRequestTime; // クールダウン管理用
  final List<String> moods = ["🥗 ヘルシー", "🍖 ガッツリ", "⏱️ 時短"];

  String _cat = "肉類", _name = "鶏むね肉", _unit = "個", _loc = "冷蔵";
  DateTime _date = DateTime.now().add(const Duration(days: 3));
  double _count = 1.0;
  bool _isFav = false;
  final List<String> units = ["個", "g", "kg", "ml", "L", "本", "枚", "パック", "合", "玉", "袋"];

  // レシート読み込み用
  bool _isReceiptLoading = false;
  List<Map<String, dynamic>> _receiptItems = [];

  // リトライバナー用
  String _retryBannerMsg = ""; // 空文字のときはバナー非表示

  final List<Map<String, dynamic>> chars = [
    {"n": "長老", "i": "🧓", "m": "フォッフォッフォ、良い食材じゃ。", "s": "～じゃ"},
    {"n": "博士", "i": "🧑‍⚕️", "m": "フム、実に興味深いデータだ。", "s": "～である"},
    {"n": "商人", "i": "🕶️", "m": "まいど！活きのいいのが入ったね！", "s": "～ですよ！"},
  ];

  // スポットライトチュートリアル用
  int _tutorialStep = -1; // -1 = 非表示
  int _guideImageIndex = 0; // 画像ガイドの現在ページ

  bool get _isTutorialActive => _tutorialStep >= 0;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (_apiKey.isEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () => _startTutorial());
      }
    });
  }

  // --- スポットライトチュートリアル ---
  void _startTutorial() {
    setState(() => _tutorialStep = 0);
  }

  void _endTutorial() {
    setState(() => _tutorialStep = -1);
  }

  // チュートリアル各ステップの定義
  List<Map<String, dynamic>> get _tutorialSteps => [
    {
      "title": "ようこそ！${chars[modeIndex]['i']}",
      "msg": "AIレシピ・レシート読み込みを使うにはGemini APIキーが必要じゃ。\n一緒に設定しよう！",
      "highlight": null, // ハイライトなし
    },
    {
      "title": "①設定を開く",
      "msg": "右上の⚙️ボタンを押してくれ！",
      "highlight": "settings", // 設定ボタンを固定座標でハイライト
    },
    {
      "title": "②Google AI Studioでキーを取得",
      "msg": "下のボタンを押すと別タブでGoogle AI Studioが開くぞ。\n画面の手順を見ながら進めてくれ！",
      "highlight": null,
      "showGuide": true, // 画像ガイドを表示
    },
    {
      "title": "③APIキーを貼り付ける",
      "msg": "コピーしたAPIキーを下のボタンから入力画面に貼り付けて「保存」を押してくれ！",
      "highlight": null,
    },
    {
      "title": "完了！🎉",
      "msg": "これでAIレシピとレシート読み込みが使えるようになるぞ。\n早速試してみてくれ！",
      "highlight": null,
    },
  ];

  // --- 計量・消費ロジック ---
  void _consumeItem(int index) {
    final item = inventory[index];
    bool isSpecial = item["name"].contains("米") || ["g", "ml", "L", "kg"].contains(item["unit"]);
    if (isSpecial) {
      _showMeasureDialog(index);
    } else {
      setState(() {
        item["count"] = (item["count"] as num).toDouble() - 1.0;
      });
      // FIX: setState の外で _save() を呼ぶ
      if ((item["count"] as num) <= 0) {
        _moveToShopping(index);
      } else {
        _save();
      }
    }
  }

  void _showMeasureDialog(int index) {
    final item = inventory[index];
    final TextEditingController cont = TextEditingController();
    bool isLiquid = ["ml", "L"].contains(item["unit"]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("${item["name"]}を使う", style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: cont,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: item["name"].contains("米") ? "何合使いましたか？" : "使用量 (${item["unit"]})",
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
          if (isLiquid) ...[
            const SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                onPressed: () => _applyMeasure(index, cont.text, "大さじ"),
                child: const Text("大さじ"),
              ),
              ElevatedButton(
                onPressed: () => _applyMeasure(index, cont.text, "小さじ"),
                child: const Text("小さじ"),
              ),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("戻る")),
          ElevatedButton(
            onPressed: () => _applyMeasure(index, cont.text, "確定"),
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  void _applyMeasure(int index, String val, String type) {
    double input = double.tryParse(val) ?? 0;
    double sub = 0;
    final item = inventory[index];

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

    setState(() {
      item["count"] = (item["count"] as num).toDouble() - sub;
    });

    // FIX: setState の外で後処理・保存
    if ((item["count"] as num) <= 0) {
      _moveToShopping(index);
    } else {
      _save();
    }

    Navigator.pop(context);
  }

  void _moveToShopping(int i) {
    final item = inventory[i];
    setState(() {
      shoppingList.add({...item, "count": 1.0});
      inventory.removeAt(i);
    });
    _speak("${_escapeSpeech(item["name"])}を使い切ったぞ。リストに追加した。");
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
        title: Text(
          "${chars[modeIndex]["i"]} ${chars[modeIndex]["n"]}の冷蔵庫",
          style: TextStyle(color: tc, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black38,
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.grid_view : Icons.view_list, color: tc),
            onPressed: () => setState(() { _isListView = !_isListView; _save(); }),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.amber),
            onPressed: () {
              if (_isTutorialActive && _tutorialStep == 1) {
                setState(() => _tutorialStep = 2);
                Future.delayed(const Duration(milliseconds: 200), _showSettings);
              } else {
                _showSettings();
              }
            },
          ),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          // リトライバナー
          if (_retryBannerMsg.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _retryBannerMsg,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                )),
              ]),
            ),
          Expanded(child: [
            _buildListTab(inventory, true, tc),
            _buildRegistration(tc),
            _buildListTab(shoppingList, false, tc),
            _buildAiTab(tc),
          ][_tabIdx]),
        ]),
        // スポットライトオーバーレイ
        if (_isTutorialActive) _buildSpotlightOverlay(context),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIdx,
        onTap: (i) => setState(() => _tabIdx = i),
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF7FFFD4),
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

  // --- 画像フルスクリーン表示 ---
  void _showFullImage(String base64, String label) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(children: [
            // 画像（ピンチズーム対応）
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  Uri.parse('data:image/jpeg;base64,$base64').data!.contentAsBytes(),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // ラベル
            Positioned(
              top: 48, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 閉じるボタン
            Positioned(
              top: 44, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            // タップで閉じるヒント
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: const Text(
                "タップして閉じる  |  ピンチで拡大",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // --- 画像付きAPIガイド ---
  Widget _buildApiImageGuide() {
    final guides = [
      {
        "img": kApiStep1Base64,
        "label": "① 「APIキーを作成」を押す",
        "arrow": "右上のボタン →",
      },
      {
        "img": kApiStep2Base64,
        "label": "② キー名はそのままで「キーを作成」を押す",
        "arrow": "右下のボタン →",
      },
      {
        "img": kApiStep3Base64,
        "label": "③ 「キーをコピー」を押してコピーする",
        "arrow": "右下のボタン →",
      },
    ];
    final guide = guides[_guideImageIndex];

    return Column(children: [
      // ページ番号
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ...List.generate(guides.length, (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _guideImageIndex ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _guideImageIndex ? Colors.amber : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        )),
      ]),
      const SizedBox(height: 8),
      // 説明テキスト
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          guide["label"]!,
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 6),
      // 画像（タップで拡大）
      GestureDetector(
        onTap: () => _showFullImage(guide["img"]!, guide["label"]!),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              Uri.parse('data:image/jpeg;base64,${guide["img"]!}').data!.contentAsBytes(),
              width: double.infinity,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          // 拡大アイコン
          Positioned(
            right: 6, bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // 前へ・次へボタン
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton(
          onPressed: _guideImageIndex > 0
              ? () => setState(() => _guideImageIndex--)
              : null,
          child: const Text("← 前へ", style: TextStyle(color: Colors.white54)),
        ),
        Text(
          "${_guideImageIndex + 1} / ${guides.length}",
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        TextButton(
          onPressed: _guideImageIndex < guides.length - 1
              ? () => setState(() => _guideImageIndex++)
              : null,
          child: const Text("次へ →", style: TextStyle(color: Colors.amber)),
        ),
      ]),
    ]);
  }

  // --- スポットライトオーバーレイ ---
  Widget _buildSpotlightOverlay(BuildContext context) {
    final step = _tutorialSteps[_tutorialStep];
    final isLast = _tutorialStep == _tutorialSteps.length - 1;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // 設定ボタンの固定座標（AppBar右上・アイコンサイズ48px想定）
    Rect? highlightRect;
    if (step["highlight"] == "settings") {
      final appBarH = kToolbarHeight + topPadding;
      highlightRect = Rect.fromLTWH(
        screenW - 56, topPadding + (kToolbarHeight - 48) / 2,
        48, 48,
      );
    }

    return GestureDetector(
      onTap: (_tutorialStep != 1) ? () {
        if (isLast) _endTutorial();
        else setState(() => _tutorialStep++);
      } : null,
      child: Stack(children: [
        // 暗いオーバーレイ（穴あきCustomPainter）
        CustomPaint(
          size: Size(screenW, screenH),
          painter: _SpotlightPainter(highlightRect),
        ),

        // 吹き出しカード（画面中央下寄り固定、ハイライトがある場合はその下）
        Positioned(
          left: 16,
          right: 16,
          bottom: highlightRect != null ? null : 80,
          top: highlightRect != null ? highlightRect.bottom + 16 : null,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ステップインジケーター + スキップ
                Row(children: [
                  ...List.generate(_tutorialSteps.length, (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: i == _tutorialStep ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _tutorialStep ? Colors.amber : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                  const Spacer(),
                  TextButton(
                    onPressed: _endTutorial,
                    child: const Text("スキップ", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 12),

                // キャラクター + タイトル
                Row(children: [
                  Text(chars[modeIndex]["i"], style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    step["title"] as String,
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                  )),
                ]),
                const SizedBox(height: 10),

                // メッセージ
                Text(
                  step["msg"] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 16),

                // ステップ別ボタン
                if (_tutorialStep == 1) ...[
                  // 設定ボタンをハイライト中：テキストのみ（ユーザーに押させる）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: const Text(
                      "⬆️ 右上の ⚙️ を押してください",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ] else if (_tutorialStep == 2) ...[
                  // 画像付き手順ガイド
                  _buildApiImageGuide(),
                  const SizedBox(height: 8),
                  // Google AI Studio を開くボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        js.context.callMethod('open', ['https://aistudio.google.com/app/apikey']);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text("Google AI Studioを開く（別タブ）"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 戻ってきた後に押すボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _tutorialStep++),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text(
                        "キーをコピーできた → 次へ ✓",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "※ 別タブが開きます。コピーしたらこの画面に戻ってきてください",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_tutorialStep == 3) ...[
                  // APIキー貼り付けボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _tutorialStep++);
                        Future.delayed(const Duration(milliseconds: 100), _promptApiKey);
                      },
                      icon: const Icon(Icons.vpn_key),
                      label: const Text("APIキーを貼り付ける"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ] else ...[
                  // 通常の次へ / はじめるボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLast) _endTutorial();
                        else setState(() => _tutorialStep++);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(isLast ? "🎉 はじめる！" : "次へ →"),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),

        // ハイライトの光るリング（設定ボタン用）
        if (highlightRect != null) ...[
          // タップ可能な透明エリア（設定ボタンの位置に重ねる）
          Positioned(
            left: highlightRect.left,
            top: highlightRect.top,
            width: highlightRect.width,
            height: highlightRect.height,
            child: GestureDetector(
              onTap: () {
                setState(() => _tutorialStep = 2);
                Future.delayed(const Duration(milliseconds: 200), _showSettings);
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // 光るリング（IgnorePointerで当たり判定なし）
          Positioned(
            left: highlightRect.left,
            top: highlightRect.top,
            child: IgnorePointer(
              child: Container(
                width: highlightRect.width,
                height: highlightRect.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.7), blurRadius: 18, spreadRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildListTab(List<dynamic> list, bool isInv, Color tc) {
    if (!_isListView && isInv) {
      // グリッド表示（在庫タブのみ）
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _itemDismissible(list[i], i, isInv),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _itemDismissible(list[i], i, isInv),
    );
  }

  // --- スワイプ機能共通化 ---
  Widget _itemDismissible(dynamic item, int i, bool isInv) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        color: isInv ? Colors.orange.withOpacity(0.6) : Colors.green.withOpacity(0.6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(isInv ? Icons.restaurant : Icons.check, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        // FIX: スワイプ後に自前で処理するため confirm で false を返し、手動で操作
        if (isInv) {
          _consumeItem(i);
        } else {
          _buyItem(i);
        }
        return false; // Dismissible 自身にはリストを変更させない（_consumeItem/_buyItem 内の setState で管理）
      },
      child: _isListView ? _itemTile(item, i, isInv) : _itemCard(item, i, isInv),
    );
  }

  Widget _itemTile(dynamic item, int i, bool isInv) {
    Color cardColor = isInv ? Colors.black45 : Colors.transparent;
    if (isInv && item["expiry"] != null) {
      final diff = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
      if (diff < 0) cardColor = Colors.red.withOpacity(0.4);
      else if (diff <= 2) cardColor = Colors.orange.withOpacity(0.4);
    }

    return Card(
      color: cardColor,
      elevation: isInv ? 1 : 0,
      child: ListTile(
        leading: Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 28)),
        title: Row(children: [
          Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (item["isFav"] == true) const Icon(Icons.star, color: Colors.amber, size: 16),
        ]),
        subtitle: Text(
          "${item["count"]}${item["unit"]} / ${item["loc"] ?? '冷蔵'}\n期限: ${item["expiry"]?.split('T')[0] ?? ''}",
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        trailing: isInv
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                onPressed: () => _consumeItem(i),
              )
            : IconButton(
                icon: const Icon(Icons.check_circle, color: Color(0xFF7FFFD4)),
                onPressed: () => _buyItem(i),
              ),
      ),
    );
  }

  Widget _itemCard(dynamic item, int i, bool isInv) {
    Color cardColor = isInv ? Colors.black45 : Colors.transparent;
    if (isInv && item["expiry"] != null) {
      final diff = DateTime.parse(item["expiry"]).difference(DateTime.now()).inDays;
      if (diff < 0) cardColor = Colors.red.withOpacity(0.4);
      else if (diff <= 2) cardColor = Colors.orange.withOpacity(0.4);
    }

    return Card(
      color: cardColor,
      elevation: isInv ? 1 : 0,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (item["isFav"] == true) const Icon(Icons.star, color: Colors.amber, size: 14),
        Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 40)),
        Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text("${item["count"]}${item["unit"]}", style: const TextStyle(color: Color(0xFF7FFFD4))),
        Text(item["loc"] ?? "冷蔵", style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 5),
        isInv
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white60),
                  onPressed: () => _consumeItem(i),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white60),
                  // FIX: setState の外で _save() を呼ぶ
                  onPressed: () {
                    setState(() { item["count"] = (item["count"] as num).toDouble() + 1.0; });
                    _save();
                  },
                ),
              ])
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7FFFD4),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _buyItem(i),
                child: const Text("購入"),
              ),
      ]),
    );
  }

  void _buyItem(int index) {
    setState(() {
      inventory.add({
        ...shoppingList[index],
        "expiry": DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      });
      shoppingList.removeAt(index);
      _sortInventory();
    });
    _speak("食材を補充した${chars[modeIndex]['s']}。");
    _save();
  }

  // --- 登録タブ ---
  Widget _buildRegistration(Color tc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── レシート読み込みセクション ──
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.receipt_long, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text("レシートから一括登録",
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            const Text("レシートの写真をアップロードするとAIが食材を読み取ります",
              style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isReceiptLoading ? null : _pickReceiptImage,
                icon: _isReceiptLoading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.upload_file),
                label: Text(_isReceiptLoading ? "読み取り中..." : "レシート画像を選択"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 50),
                ),
              ),
            ),
            // 読み取り結果プレビュー
            if (_receiptItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text("${_receiptItems.length}品を読み取りました。確認して登録してください。",
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              ..._receiptItems.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Text(item["icon"] ?? "📦", style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("${item["unit"]} / ${item["loc"]} / 期限${item["limit"]}日",
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ])),
                    // 個別削除ボタン
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _receiptItems.removeAt(idx)),
                    ),
                  ]),
                );
              }),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: _addAllReceiptItems,
                  icon: const Icon(Icons.kitchen),
                  label: Text("全て在庫へ登録 (${_receiptItems.length}品)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7FFFD4),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 50),
                  ),
                )),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _receiptItems.clear()),
                  icon: const Icon(Icons.delete_sweep, color: Colors.white38),
                  tooltip: "リストをクリア",
                ),
              ]),
            ],
          ]),
        ),

        const SizedBox(height: 20),
        const Divider(color: Colors.white24),
        const SizedBox(height: 10),
        const Text("── または手動で登録 ──",
          style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 15),
        _label("1. カテゴリー"),
        _dropdown(foodMaster.keys.toList(), _cat, (v) => setState(() {
          _cat = v!;
          _name = foodMaster[v]![0]["name"];
        })),
        const SizedBox(height: 15),
        _label("2. 食材"),
        ListTile(
          tileColor: Colors.black38,
          title: Text(_name, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.arrow_drop_down, color: Colors.white),
          onTap: _showFoodSelector,
        ),
        const SizedBox(height: 15),
        _label("3. 保管場所"),
        _dropdown(["冷蔵", "冷凍", "野菜室", "常温"], _loc, (v) => setState(() => _loc = v!)),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label("4. 単位"),
            _dropdown(units, _unit, (v) => setState(() => _unit = v!)),
          ])),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label("5. 期限"),
            ElevatedButton(
              onPressed: () async {
                var p = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (p != null) setState(() => _date = p);
              },
              child: Text("${_date.year}/${_date.month}/${_date.day}"),
            ),
          ])),
        ]),
        const SizedBox(height: 15),
        _label("6. 数量"),
        TextField(
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.black38,
            hintText: "1.0",
          ),
          onChanged: (v) => _count = double.tryParse(v) ?? 1.0,
        ),
        Row(children: [
          const Text("お気に入り", style: TextStyle(color: Colors.white70)),
          Switch(value: _isFav, activeColor: Colors.amber, onChanged: (v) => setState(() => _isFav = v)),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _add(true),
            icon: const Icon(Icons.kitchen),
            label: const Text("在庫へ"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7FFFD4),
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 60),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _add(false),
            icon: const Icon(Icons.shopping_cart),
            label: const Text("買い物へ"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 60),
            ),
          )),
        ]),
      ]),
    );
  }

  void _add(bool toInv) {
    var data = {
      "name": _name,
      "icon": _getIcon(_name),
      "count": _count,
      "unit": _unit,
      "expiry": _date.toIso8601String(),
      "isFav": _isFav,
      "loc": _loc,
    };
    setState(() {
      if (toInv) inventory.add(data);
      else shoppingList.add(data);
      _sortInventory();
    });
    _speak("${_escapeSpeech(_name)}を追加したぞ。");
    _save();
  }

  // --- レシート読み込み ---
  void _pickReceiptImage() {
    if (_apiKey.isEmpty) { _promptApiKey(); return; }
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();
    input.onChange.listen((e) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoad.listen((_) {
        final dataUrl = reader.result as String;
        final base64 = dataUrl.split(',').last;
        final mimeType = dataUrl.split(';').first.split(':').last;
        setState(() {
          _isReceiptLoading = true;
          _receiptItems.clear();
        });
        _analyzeReceipt(base64, mimeType);
      });
    });
  }

  Future<void> _analyzeReceipt(String base64, String mimeType) async {
    // クールダウン: RPM5制限に合わせて15秒
    final now = DateTime.now();
    if (_lastRequestTime != null && now.difference(_lastRequestTime!).inSeconds < 15) {
      setState(() => _isReceiptLoading = false);
      _showSnack("少し待ってからもう一度試してくれ${chars[modeIndex]['s']}。");
      return;
    }
    _lastRequestTime = now;

    // リトライ設定: 最大3回、待機時間 30→60→120秒
    const maxRetry = 3;
    final waitSecs = [30, 60, 120];

    for (int retry = 0; retry < maxRetry; retry++) {
      try {
        // バナー表示
        setState(() {
          _retryBannerMsg = retry == 0
              ? "🔍 レシートを解析中${chars[modeIndex]['s']}..."
              : "🔄 再試行中 (${retry + 1}/$maxRetry)... しばらく待っておくれ${chars[modeIndex]['s']}。";
        });

        final prompt = """
このレシートまたは食材の画像を解析して、食材・食品のみを抽出してください。
日用品・消耗品（洗剤、ティッシュ等）は除外してください。

以下のJSON形式のみで返答してください。余分なテキストや```は不要です。
[
  {"name":"食材名","unit":"個","loc":"冷蔵","limit":3},
  ...
]

unitは ["個","g","kg","ml","L","本","枚","パック","合","玉","袋"] から最適なものを選択。
locは ["冷蔵","冷凍","野菜室","常温"] から最適なものを選択。
limitは消費期限の目安日数（整数）。
食材名は短く簡潔に（例：「国産鶏むね肉」→「鶏むね肉」）。
""";

        final res = await http.post(
          Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [{
              "parts": [
                {"inline_data": {"mime_type": mimeType, "data": base64}},
                {"text": prompt}
              ]
            }]
          }),
        ).timeout(const Duration(seconds: 40));

        if (res.statusCode == 200) {
          // 成功
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          String text = decoded['candidates'][0]['content']['parts'][0]['text'];
          final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
          if (jsonMatch != null) {
            final List<dynamic> items = jsonDecode(jsonMatch.group(0)!);
            setState(() {
              _receiptItems = items.map((item) {
                final name = item["name"] as String;
                final limit = (item["limit"] as num?)?.toInt() ?? 3;
                return {
                  "name": name,
                  "icon": _getIcon(name),
                  "unit": item["unit"] ?? "個",
                  "loc": item["loc"] ?? "冷蔵",
                  "limit": limit,
                  "count": 1.0,
                  "isFav": false,
                  "expiry": DateTime.now().add(Duration(days: limit)).toIso8601String(),
                };
              }).toList();
              // 成功したらバナーを消す
              _retryBannerMsg = "";
            });
            _speak("レシートから${_receiptItems.length}品読み取った${chars[modeIndex]['s']}。");
          } else {
            setState(() => _retryBannerMsg = "");
            _showSnack("食材を読み取れなかった${chars[modeIndex]['s']}。別の画像を試してくれ。");
          }
          break; // 成功したのでループを抜ける

        } else if (res.statusCode == 429) {
          // リクエスト過多 → 待機してリトライ
          if (retry < maxRetry - 1) {
            final wait = waitSecs[retry];
            // カウントダウン表示
            for (int s = wait; s > 0; s--) {
              setState(() {
                _retryBannerMsg = "⏳ APIが混雑中${chars[modeIndex]['s']}。${s}秒後に自動で再試行する...";
              });
              await Future.delayed(const Duration(seconds: 1));
            }
            _lastRequestTime = DateTime.now(); // リトライ時刻を更新
            continue; // 次のリトライへ
          } else {
            // 3回全部失敗
            setState(() => _retryBannerMsg = "");
            _showSnack("何度試しても混雑中${chars[modeIndex]['s']}。時間をおいてから試してくれ。");
          }

        } else if (res.statusCode == 400) {
          setState(() => _retryBannerMsg = "");
          _showSnack("APIキーが無効${chars[modeIndex]['s']}。設定を確認してくれ。");
          break;
        } else {
          setState(() => _retryBannerMsg = "");
          _showSnack("エラーが発生した（コード: ${res.statusCode}）${chars[modeIndex]['s']}。");
          break;
        }

      } on TimeoutException {
        setState(() => _retryBannerMsg = "");
        _showSnack("タイムアウトじゃ。もう一度試してくれ。");
        break;
      } catch (e) {
        setState(() => _retryBannerMsg = "");
        _showSnack("予期せぬエラーじゃ: $e");
        break;
      }
    }

    setState(() {
      _isReceiptLoading = false;
      _retryBannerMsg = "";
    });
  }

  void _addAllReceiptItems() {
    if (_receiptItems.isEmpty) return;
    setState(() {
      for (final item in _receiptItems) {
        inventory.add({...item});
      }
      _sortInventory();
      _receiptItems.clear();
    });
    _speak("${inventory.length}品を在庫に追加した${chars[modeIndex]['s']}。");
    _save();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.grey[800]),
    );
  }

  // --- AIタブ ---
  Widget _buildAiTab(Color tc) => Column(children: [
    Padding(padding: const EdgeInsets.all(15), child: Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: moods.map((m) => ChoiceChip(
          label: Text(m),
          selected: _aiMood == m,
          onSelected: (s) => setState(() => _aiMood = m),
        )).toList(),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        icon: const Icon(Icons.auto_awesome),
        label: Text(_isAiLoading ? "思考中..." : "レシピ提案"),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
        onPressed: _isAiLoading ? null : _generateRecipe,
      ),
    ])),
    Expanded(child: Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
      child: SingleChildScrollView(child: Column(children: [
        Text(
          _aiResult.isEmpty ? "提案を待っておるぞ。" : _aiResult,
          style: const TextStyle(color: Colors.white, height: 1.5),
        ),
        if (_aiResult.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 15),
          child: ElevatedButton.icon(
            onPressed: _saveRecipe,
            icon: const Icon(Icons.bookmark),
            label: const Text("このレシピを保存する"),
          ),
        ),
      ])),
    )),
  ]);

  void _saveRecipe() {
    final title = "$_aiMoodのレシピ";
    setState(() => favoriteRecipes.add({
      "title": title,
      "body": _aiResult,
      "date": DateFormat('MM/dd').format(DateTime.now()),
    }));
    _save();
    _speak("レシピを保存した${chars[modeIndex]['s']}。設定から見れるぞい。");
  }

  // --- 設定画面 ---
  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("アプリ設定", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.amber),
            title: const Text("チュートリアルを見る", style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _startTutorial(); },
          ),
          ListTile(
            leading: const Icon(Icons.book, color: Colors.amber),
            title: const Text("保存したレシピ", style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _showRecipeBook(); },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new, color: Colors.amber),
            title: const Text("APIキーを取得", style: TextStyle(color: Colors.white)),
            onTap: () => js.context.callMethod('open', ['https://aistudio.google.com/app/apikey']),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key, color: Colors.amber),
            title: const Text("APIキーを保存", style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _promptApiKey(); },
          ),
          const Divider(color: Colors.white24),
          ...List.generate(3, (i) => ListTile(
            leading: Text(chars[i]["i"]),
            title: Text(chars[i]["n"], style: const TextStyle(color: Colors.white)),
            onTap: () { setState(() => modeIndex = i); _save(); Navigator.pop(ctx); },
          )),
        ])),
      ),
    );
  }

  void _showRecipeBook() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => favoriteRecipes.isEmpty
          ? const Center(child: Text("レシピはありません", style: TextStyle(color: Colors.white)))
          : ListView.builder(
              itemCount: favoriteRecipes.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(favoriteRecipes[i]["title"], style: const TextStyle(color: Colors.white)),
                subtitle: Text(favoriteRecipes[i]["date"], style: const TextStyle(color: Colors.white38)),
                onTap: () => showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: Text(favoriteRecipes[i]["title"]),
                    content: SingleChildScrollView(
                      child: Text(favoriteRecipes[i]["body"], style: const TextStyle(color: Colors.white)),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text("閉じる")),
                      TextButton(
                        onPressed: () {
                          setState(() => favoriteRecipes.removeAt(i));
                          _save();
                          Navigator.pop(d);
                          Navigator.pop(ctx);
                        },
                        child: const Text("削除", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- システム・保存 ---
  void _promptApiKey() {
    TextEditingController c = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("API Key設定", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: c,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(fillColor: Colors.white10, filled: true),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => _apiKey = c.text);
              _save();
              Navigator.pop(ctx);
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  void _sortInventory() {
    inventory.sort((a, b) =>
        (a['expiry'] ?? "9999-12-31").compareTo(b['expiry'] ?? "9999-12-31"));
  }

  Future<void> _generateRecipe() async {
    if (_apiKey.isEmpty) { _promptApiKey(); return; }

    // クールダウン: RPM5制限に合わせて15秒
    final now = DateTime.now();
    if (_lastRequestTime != null && now.difference(_lastRequestTime!).inSeconds < 15) {
      setState(() => _aiResult = "少し待ってからもう一度試してくれ${chars[modeIndex]['s']}。");
      return;
    }
    _lastRequestTime = now;

    setState(() { _isAiLoading = true; _aiResult = ""; });
    try {
      final res = await http.post(
        Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"contents": [{"parts": [{"text":
          "あなたは${chars[modeIndex]["n"]}です。語尾は${chars[modeIndex]["s"]}を使って。"
          "${inventory.map((e) => e['name']).join(',')}で${_aiMood}なレシピを作って。"
        }]}]}),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() => _aiResult = decoded['candidates'][0]['content']['parts'][0]['text']);
      } else if (res.statusCode == 400) {
        setState(() => _aiResult = "APIキーが無効${chars[modeIndex]['s']}。設定を確認してくれ。");
      } else if (res.statusCode == 429) {
        setState(() => _aiResult = "リクエストが多すぎる${chars[modeIndex]['s']}。1分ほど待ってから試してくれ。");
      } else {
        setState(() => _aiResult = "エラーが発生した（コード: ${res.statusCode}）${chars[modeIndex]['s']}。しばらく待って試してくれ。");
      }
    } on TimeoutException {
      setState(() => _aiResult = "タイムアウトじゃ。通信環境を確認してもう一度試してくれ。");
    } on http.ClientException {
      setState(() => _aiResult = "ネットワークに接続できないぞ。通信環境を確認してくれ。");
    } catch (e) {
      setState(() => _aiResult = "予期せぬエラーじゃ。もう一度試してくれ。");
    }
    setState(() => _isAiLoading = false);
  }

  void _save() async {
    final p = await SharedPreferences.getInstance();
    p.setString('inv', jsonEncode(inventory));
    p.setString('shop', jsonEncode(shoppingList));
    p.setString('fav_recipes', jsonEncode(favoriteRecipes));
    p.setInt('mode', modeIndex);
    p.setInt('color', customColor.value);
    p.setString('apiKey', _apiKey);
    p.setBool('isListView', _isListView);
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      inventory = jsonDecode(p.getString('inv') ?? "[]");
      shoppingList = jsonDecode(p.getString('shop') ?? "[]");
      favoriteRecipes = jsonDecode(p.getString('fav_recipes') ?? "[]");
      modeIndex = p.getInt('mode') ?? 0;
      int? cVal = p.getInt('color');
      if (cVal != null) customColor = Color(cVal);
      _apiKey = p.getString('apiKey') ?? "";
      _isListView = p.getBool('isListView') ?? true;
      _sortInventory();
    });
  }

  // FIX: シングルクォートをエスケープして JS クラッシュを防止
  String _escapeSpeech(String t) => t.replaceAll("'", "\\'");

  void _speak(String t) => js.context.callMethod('eval', [
    "window.speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance('$t'); u.lang = 'ja-JP'; window.speechSynthesis.speak(u);"
  ]);

  void _showFoodSelector() {
    var list = foodMaster[_cat] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(list[i]["name"], style: const TextStyle(color: Colors.white)),
          onTap: () { setState(() => _name = list[i]["name"]); Navigator.pop(ctx); },
        ),
      ),
    );
  }

  String _getIcon(String n) {
    for (var l in foodMaster.values) {
      for (var i in l) {
        if (i["name"] == n) return i["icon"];
      }
    }
    return "📦";
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(s, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
  );

  Widget _dropdown(List<String> items, String val, ValueChanged<String?> onC) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
    child: DropdownButton<String>(
      value: val,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
      onChanged: onC,
      isExpanded: true,
      underline: Container(),
      dropdownColor: Colors.black87,
    ),
  );
}

// スポットライト用カスタムペインター（ハイライト箇所だけ穴を開ける）
class _SpotlightPainter extends CustomPainter {
  final Rect? highlightRect;
  _SpotlightPainter(this.highlightRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.75);
    if (highlightRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    } else {
      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(highlightRect!, const Radius.circular(8)))
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.highlightRect != highlightRect;
}