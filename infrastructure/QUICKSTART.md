# Logic Factory - クイックスタートガイド

## 🚀 5分で起動

### 1. 環境変数の設定

```bash
cd infrastructure
cp .env.example .env
```

`.env` ファイルを編集して、以下のパスワードとキーを設定：

```bash
# 最低限変更が必要な項目
POSTGRES_PASSWORD=your-strong-password-here
DIFY_SECRET_KEY=your-secret-key-here-min-32-chars
REDIS_PASSWORD=your-redis-password-here
DIFY_API_KEY=your-llm-api-key-here  # OpenAI/Anthropic等のAPIキー
```

### 2. 起動

```bash
docker compose up -d
```

### 3. アクセス

起動完了まで2-3分待機してから：

- **n8n**: http://localhost:5678
- **Dify**: http://localhost:80

## ✅ 動作確認

```bash
# 全コンテナのステータス確認
docker compose ps

# 全て "Up (healthy)" になっていればOK
```

## 📊 ステータス確認

| サービス | 確認方法 |
|:---------|:---------|
| PostgreSQL | `docker compose exec db psql -U logicfactory -l` |
| Redis | `docker compose exec redis redis-cli ping` |
| n8n | http://localhost:5678/healthz |
| Dify | http://localhost/health |

## 🛠 トラブルシューティング

### コンテナが起動しない

```bash
# ログ確認
docker compose logs <service-name>

# 全て再起動
docker compose down && docker compose up -d
```

### ポート競合

既にポート5678または80が使用されている場合：

```bash
# ポート使用状況を確認
lsof -i :5678
lsof -i :80
```

`docker-compose.yml` の `ports` セクションを変更して別のポートを使用してください。

### データのリセット

```bash
# 警告: 全データが削除されます
docker compose down -v
docker compose up -d
```

## 📚 次のステップ

- [詳細なREADME](./README.md) - 全コマンドとトラブルシューティング
- [設計仕様書](./docs/spec.md) - アーキテクチャの詳細
- [n8nドキュメント](https://docs.n8n.io/)
- [Difyドキュメント](https://docs.dify.ai/)
