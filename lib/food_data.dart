// 食材マスターデータ：カテゴリ、食材名、アイコン、消費期限(日)を定義
final Map<String, List<Map<String, dynamic>>> foodMaster = {
  "肉類": [
    {"name": "鶏むね肉", "icon": "🍗", "limit": 2},
    {"name": "鶏もも肉", "icon": "🍗", "limit": 2},
    {"name": "豚バラ肉", "icon": "🥩", "limit": 3},
    {"name": "牛ステーキ肉", "icon": "🥩", "limit": 3},
    {"name": "ひき肉", "icon": "🥡", "limit": 1},
    {"name": "ハム・ソーセージ", "icon": "🥓", "limit": 7},
  ],
  "魚介類": [
    {"name": "鮭の切り身", "icon": "🐟", "limit": 3},
    {"name": "刺身", "icon": "🍣", "limit": 1},
    {"name": "えび・いか", "icon": "🦐", "limit": 2},
    {"name": "あじ・いわし", "icon": "🐟", "limit": 2},
  ],
  "野菜": [
    {"name": "キャベツ", "icon": "🥬", "limit": 7},
    {"name": "たまねぎ", "icon": "🧅", "limit": 21},
    {"name": "にんじん", "icon": "🥕", "limit": 14},
    {"name": "もやし", "icon": "🌱", "limit": 2},
    {"name": "ブロッコリー", "icon": "🥦", "limit": 4},
  ],
  "果物": [
    {"name": "りんご", "icon": "🍎", "limit": 14},
    {"name": "バナナ", "icon": "🍌", "limit": 5},
    {"name": "いちご", "icon": "🍓", "limit": 2},
  ],
  "飲み物": [
    {"name": "牛乳", "icon": "🥛", "limit": 5},
    {"name": "お茶", "icon": "🍵", "limit": 4},
    {"name": "ジュース", "icon": "🧃", "limit": 4},
    {"name": "ビール", "icon": "🍺", "limit": 30},
  ],
  "調味料": [
    {"name": "マヨネーズ", "icon": "🧴", "limit": 30},
    {"name": "ケチャップ", "icon": "🍅", "limit": 30},
    {"name": "味噌", "icon": "🍲", "limit": 90},
  ],
  "キノコ類": [
    {"name": "しいたけ", "icon": "🍄", "limit": 5},
    {"name": "しめじ", "icon": "🍄", "limit": 5},
  ],
  "お菓子": [
    {"name": "チョコ", "icon": "🍫", "limit": 30},
    {"name": "アイス", "icon": "🍦", "limit": 60},
    {"name": "ケーキ", "icon": "🍰", "limit": 1},
  ],
};