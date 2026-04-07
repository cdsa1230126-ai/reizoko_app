import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:html' as html; // Web用の音声・通知機能

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // カメラの準備（Webブラウザで許可が必要）
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("カメラが見つかりません: $e");
  }
  runApp(ReizokoApp(cameras: cameras));
}

class ReizokoApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ReizokoApp({super.key, required this.cameras});

  @override
  State<ReizokoApp> createState() => _ReizokoAppState();
}

class _ReizokoAppState extends State<ReizokoApp> {
  Color themeColor = Colors.green; 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '冷蔵庫RPG',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
        useMaterial3: true,
      ),
      home: ReizokoHomePage(cameras: widget.cameras),
    );
  }
}

class ReizokoHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ReizokoHomePage({super.key, required this.cameras});

  @override
  State<ReizokoHomePage> createState() => _ReizokoHomePageState();
}

class _ReizokoHomePageState extends State<ReizokoHomePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> inventory = [];
  List<String> shoppingList = [];
  String characterMode = "長老"; 
  String apiKey = "";
  
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: "1");
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3));
  String _selectedIcon = "🍎";

  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    
    // 起動時に通知の許可を求める
    _requestNotificationPermission();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  // --- 通知機能 ---
  void _requestNotificationPermission() {
    if (html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  }

  void _showNotification(String title, String body) {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  }

  // --- データの読み込み・保存 ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      inventory = List<Map<String, dynamic>>.from(json.decode(prefs.getString('inventory') ?? '[]'));
      shoppingList = prefs.getStringList('shoppingList') ?? [];
      characterMode = prefs.getString('characterMode') ?? "長老";
      apiKey = prefs.getString('apiKey') ?? "";
    });
    _checkExpiryAlert();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', json.encode(inventory));
    await prefs.setStringList('shoppingList', shoppingList);
    await prefs.setString('characterMode', characterMode);
    await prefs.setString('apiKey', apiKey);
  }

  // --- 音声とアラート ---
  void _speak(String text) {
    final utterance = html.SpeechSynthesisUtterance(text)..lang = 'ja-JP';
    html.window.speechSynthesis?.speak(utterance);
  }

  void _checkExpiryAlert() {
    List<String> urgentItems = [];
    for (var item in inventory) {
      final expiry = DateTime.parse(item['expiry']);
      if (expiry.difference(DateTime.now()).inDays <= 1) {
        urgentItems.add(item['name']);
      }
    }

    if (urgentItems.isNotEmpty) {
      String msg = characterMode == "長老" ? "警告じゃ！${urgentItems.join(', ')}が腐りそうじゃぞ！" : "期限間近の食材があります。";
      // 音声
      Future.delayed(const Duration(seconds: 2), () => _speak(msg));
      // ブラウザ通知
      _showNotification("【冷蔵庫RPG 警告】", "${urgentItems.length}個の食材が期限間近です！");
    }
  }

  // --- 操作ロジック ---
  void _addItem() {
    if (_itemController.text.isEmpty) return;
    setState(() {
      inventory.add({
        "name": _itemController.text,
        "icon": _selectedIcon,
        "count": int.tryParse(_countController.text) ?? 1,
        "expiry": _selectedDate.toIso8601String(),
      });
      _itemController.clear();
      _countController.text = "1";
    });
    _saveData();
    _speak(characterMode == "長老" ? "新しい獲物じゃ！" : "追加しました。");
  }

  void _consumeItem(int index) {
    setState(() {
      String name = inventory[index]['name'];
      if (inventory[index]['count'] > 1) {
        inventory[index]['count'] -= 1;
      } else {
        shoppingList.add(name);
        inventory.removeAt(index);
      }
    });
    _saveData();
    _speak(characterMode == "長老" ? "見事な討伐じゃ！" : "消費しました。");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("冷蔵庫RPG ($characterMode)"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings),
        ],
      ),
      body: Column(
        children: [
          _buildInputArea(),
          const Divider(),
          Expanded(child: _buildInventoryList()),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            children: [
              DropdownButton<String>(
                value: _selectedIcon,
                items: ["🍎", "🥩", "🥦", "🥛", "🐟"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                onChanged: (v) => setState(() => _selectedIcon = v!),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _itemController, decoration: const InputDecoration(labelText: "食材名", border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              SizedBox(width: 60, child: TextField(controller: _countController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "数", border: OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.add_box, color: Colors.green, size: 40), onPressed: _addItem),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (date != null) setState(() => _selectedDate = date);
            },
            label: Text("賞味期限: ${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}"),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    return ListView.builder(
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final expiry = DateTime.parse(item['expiry']);
        final isUrgent = expiry.difference(DateTime.now()).inDays <= 1;

        return AnimatedBuilder(
          animation: _blinkController,
          builder: (context, child) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: isUrgent ? Colors.red.withOpacity(0.1 + 0.3 * _blinkController.value) : Colors.white,
              shape: isUrgent ? RoundedRectangleBorder(side: const BorderSide(color: Colors.red, width: 2), borderRadius: BorderRadius.circular(8)) : null,
              child: ListTile(
                leading: Text(item['icon'], style: const TextStyle(fontSize: 30)),
                title: Text(item['name'], style: TextStyle(fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal, color: isUrgent ? Colors.red.shade900 : Colors.black)),
                subtitle: Text("期限: ${expiry.month}/${expiry.day} | 残り: ${item['count']}個"),
                trailing: IconButton(
                  icon: const Icon(Icons.restaurant, color: Colors.orange, size: 30),
                  onPressed: () => _consumeItem(index),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("冒険の設定"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("キャラクター選択"),
            DropdownButton<String>(
              value: characterMode,
              isExpanded: true,
              items: ["長老", "ドクター", "トレーダー"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                setState(() => characterMode = v!);
                _saveData();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
            const Text("AI APIキー"),
            TextField(
              controller: TextEditingController(text: apiKey),
              onChanged: (v) => apiKey = v,
              decoration: const InputDecoration(hintText: "Gemini Keyを入力"),
            ),
          ],
        ),
      ),
    );
  }
}