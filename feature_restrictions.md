# Gymnastics AI 機能制限定義

## 無料版（Free Tier）

### ✅ 利用可能な機能
- **基本的な体操技データベース**（200技まで）
- **基本的なD-スコア計算**（簡易版）
- **演技構成の作成・保存**（3つまで）
- **AIチャット**（1日10回まで）
- **技の検索・フィルタリング**（基本機能のみ）

### ❌ 制限される機能
- 全技データベース（799技中599技が制限）
- 詳細なD-スコア分析
- 無制限の演技構成保存
- 高度なAI分析機能
- つなぎ加点の詳細計算
- 構成要求の詳細分析
- エクスポート機能
- バックアップ・同期機能

### 📱 その他の制限
- **広告表示**（バナー広告）
- **機能へのアクセス時にアップグレード促進**

---

## プレミアム版（Premium Tier）

### ✅ 全機能利用可能
- **全技データベース**（799技すべて）
- **詳細なD-スコア計算**
- **無制限の演技構成保存**
- **AIチャット無制限**
- **高度な分析機能**
- **つなぎ加点計算**
- **構成要求分析**
- **エクスポート機能**
- **バックアップ・同期**
- **広告非表示**

---

## 実装における制限ポイント

### 1. スキルデータベース制限
```dart
List<Skill> getAvailableSkills() {
  if (_userSubscription.tier == UserTier.free) {
    return _allSkills.take(200).toList(); // 200技まで
  }
  return _allSkills; // 全技
}
```

### 2. AIチャット制限
```dart
bool canSendChatMessage() {
  if (_userSubscription.tier == UserTier.free) {
    return _dailyChatCount < 10;
  }
  return true;
}
```

### 3. 演技構成保存制限
```dart
bool canSaveRoutine() {
  if (_userSubscription.tier == UserTier.free) {
    return _savedRoutines.length < 3;
  }
  return true;
}
```

### 4. 高度な分析機能制限
```dart
bool canAccessAdvancedAnalysis() {
  return _userSubscription.tier == UserTier.premium;
}
```

### 5. 広告表示制御
```dart
bool shouldShowAds() {
  return _userSubscription.tier == UserTier.free;
}
```

---

## UI/UX での制限表示

### プレミアム機能への誘導
- 🔒 ロックアイコン表示
- 💎 "プレミアム" バッジ
- ⬆️ "アップグレード" ボタン

### 制限に達した時の表示
- 📊 "1日の利用制限に達しました"
- 💾 "保存可能な演技構成数の上限です"
- 🔓 "プレミアムにアップグレードして制限を解除"

---

## 課金促進戦略

### 1. 段階的な制限
- 最初は基本機能を体験
- 高度な機能使用時に制限を感じる
- 自然な形でアップグレードを促す

### 2. 価値の明確化
- プレミアム機能の具体的なメリット
- 時間短縮・効率化の価値
- プロレベルの分析機能

### 3. 適切なタイミング
- 機能を使い慣れたタイミング
- 制限に達したタイミング
- 重要な大会前など