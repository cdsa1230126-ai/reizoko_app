import streamlit as st

# --- 初期データの設定 (セッション状態) ---
if 'inventory' not in st.session_state:
    st.session_state.inventory = {
        "コメ": 5000,  # 単位: g
        "卵": 10,     # 単位: 個
        "玉ねぎ": 3,   # 単位: 個
        "鶏もも肉": 2  # 単位: 枚
    }

st.title("📦 スマート食材管理")

# --- 1. 食材リストの個数変更セクション ---
st.header("🛒 在庫リストの編集")
st.caption("リスト内の数値を変更すると直接在庫が更新されます。")

updated_inventory = {}
for item, amount in st.session_state.inventory.items():
    unit = "g" if item == "コメ" else "個/枚"
    # 数値入力フォームで個数を変更可能にする
    new_val = st.number_input(f"{item} ({unit})", min_value=0, value=amount, key=f"input_{item}")
    updated_inventory[item] = new_val

# 在庫データの更新
st.session_state.inventory = updated_inventory


st.divider()

# --- 2. お米の消費（合単位）セクション ---
st.header("🍚 お米を炊く")
col1, col2 = st.columns([2, 1])

with col1:
    consume_go = st.number_input("何合消費しますか？", min_value=0.1, max_value=10.0, value=1.0, step=0.5)
    
with col2:
    if st.button("消費実行"):
        # 1合 = 150g として計算
        consume_gram = int(consume_go * 150)
        
        if st.session_state.inventory["コメ"] >= consume_gram:
            st.session_state.inventory["コメ"] -= consume_gram
            st.success(f"お米を {consume_go}合 ({consume_gram}g) 減らしました！")
            st.rerun() # 画面をリフレッシュして在庫に反映
        else:
            st.error("在庫が足りません！")

# --- おまけ：現在の在庫状況を可視化 ---
st.sidebar.header("📊 現在の在庫状況")
for item, amount in st.session_state.inventory.items():
    if item == "コメ":
        st.sidebar.write(f"🌾 {item}: {amount}g (約{round(amount/150, 1)}合)")
    else:
        st.sidebar.write(f"🔹 {item}: {amount}")