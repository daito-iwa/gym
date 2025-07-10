# Bashツール修復ガイド

## 🚨 **現在の問題**
```
zsh:source:1: no such file or directory: /var/folders/9l/b1477_js7w34vwcy46q2v4vh0000gn/T/claude-shell-snapshot-eb62
```

## 🔧 **修復手順**

### Step 1: 修復スクリプトの実行
```bash
cd /Users/iwasakihiroto/Desktop/gym
chmod +x fix_bash_tool.sh
./fix_bash_tool.sh
```

### Step 2: 手動クリーンアップ（スクリプトが失敗した場合）
```bash
# 一時ディレクトリのクリーンアップ
sudo rm -rf /var/folders/*/T/claude-shell-snapshot-*
rm -rf ~/Library/Caches/Claude*
rm -rf ~/.cache/Claude*

# 権限の修正
sudo chmod 755 /var/folders/
sudo chmod 1777 /tmp/

# システムクリーンアップ
sudo periodic daily
```

### Step 3: Claude Codeの再起動
1. **Claude Codeを完全に終了**
2. **再度起動**
3. **新しいチャットセッションを開始**

### Step 4: 動作確認
新しいセッションで以下のコマンドをテスト：
```bash
echo "test"
pwd
ls
```

## 🔍 **トラブルシューティング**

### 問題が継続する場合
1. **macOSの再起動**
2. **Claude Codeの再インストール**
3. **システムの権限設定確認**

### 権限エラーが発生する場合
```bash
# 管理者権限で実行
sudo -i
rm -rf /var/folders/*/T/claude-shell-snapshot-*
chmod 755 /var/folders/
chmod 1777 /tmp/
exit
```

### 環境変数の問題
```bash
# 環境変数の確認
echo $SHELL
echo $PATH
echo $TMPDIR

# 必要に応じて設定
export TMPDIR=/tmp
export SHELL=/bin/zsh
```

## 🚀 **予防策**

### 定期的なメンテナンス
```bash
# 週1回程度実行
sudo periodic daily weekly monthly
rm -rf ~/Library/Caches/Claude*
```

### システム設定の最適化
1. **十分なディスク容量確保**
2. **適切な権限設定維持**
3. **定期的なシステム更新**

## 📋 **チェックリスト**

修復後に以下を確認：

- [ ] 修復スクリプトの実行完了
- [ ] Claude Codeの再起動完了
- [ ] 新しいチャットセッション開始
- [ ] Bashツールの動作確認
- [ ] 基本コマンドの実行テスト

## 💡 **最終手段**

上記すべてが失敗した場合：

1. **システム再起動**
2. **Claude Codeの再インストール**
3. **macOSのシステム整合性チェック**
   ```bash
   sudo /usr/libexec/repair_packages --repair --standard-pkgs
   ```

## 🎯 **期待される結果**

修復後、以下が正常に動作する：
- ✅ 基本的なBashコマンド実行
- ✅ ファイルシステムアクセス
- ✅ 権限チェック
- ✅ 一時ファイル作成

---

**この手順を実行後、Bashツールが正常に動作するはずです。**