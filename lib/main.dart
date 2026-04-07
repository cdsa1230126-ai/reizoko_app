import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const ReizokoApp());
}

class ReizokoApp extends StatelessWidget {
  const ReizokoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '冷蔵庫RPG',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const ReizokoHomePage(),
    );
  }
}

class ReizokoHomePage extends StatefulWidget {
  const ReizokoHomePage({super.key});
  @override
  State<ReizokoHomePage> createState() => _ReizokoHomePageState();
}

class _ReizokoHomePageState extends State<ReizokoHomePage> {
  List<Map<String, dynamic>> inventory = [];
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: "1"); // 初期値を1に設定

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  // データの読み込み
  Future<void> _loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('inventory');
    if (data != null) {
      setState(() {
        inventory = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  // データの保存
  Future<void> _saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory', json.encode(inventory));
  }

  // 食材の追加（個数対応）
  void _addItem() {
    if (_itemController.text.isEmpty) return;
    
    // 入力された文字を数字に変換（失敗したら1にする）
    int count = int.tryParse(_countController.text) ?? 1;

    setState(() {
      inventory.add({
        "name": _itemController.text,
        "icon": "🍱", // アイコン選択機能がないので一旦固定
        "count": count,
        "added_at": DateTime.now().toString(),
      });
      _itemController.clear();
      _countController.text = "1"; // 入力欄をリセット
    });
    _saveInventory();
  }

  // 【新機能】レシピを作って食材を消費する
  void _cookAndConsume() {
    if (inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("冷蔵庫が空っぽです！冒険に出かけましょう。")),
      );
      return;
    }

    setState(() {
      // 全ての食材を1つずつ減らす（RPGの「アイテム消費」演出）
      for (var item in inventory) {
        if (item["count"] > 0) {
          item["count"] -= 1;
        }
      }
      // 個数が0になったものをリストから削除
      inventory.removeWhere((item) => item["count"] <= 0);
    });
    _saveInventory();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("料理が完成！食材を1つずつ消費しました。")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("冷蔵庫RPG - 在庫管理")),
      body: Column(
        children: [
          // 入力エリア
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(
                      labelText: "食材の名前",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "個数",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_box, color: Colors.orange, size: 40),
                  onPressed: _addItem,
                ),
              ],
            ),
          ),

          // 消費ボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _cookAndConsume,
              icon: const Icon(Icons.restaurant),
              label: const Text("レシピを作成して消費！"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const Divider(height: 32),

          // 在庫リスト表示
          Expanded(
            child: inventory.isEmpty 
              ? const Center(child: Text("冷蔵庫に食材がありません"))
              : ListView.builder(
                  itemCount: inventory.length,
                  itemBuilder: (context, index) {
                    final item = inventory[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Text("🍱", style: TextStyle(fontSize: 24)),
                        title: Text(item["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "x ${item["count"]}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        onLongPress: () {
                          // 長押しで削除
                          setState(() {
                            inventory.removeAt(index);
                            _saveInventory();
                          });
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}