# Logic Factory - クイックスタートガイド

## 🚀 5分で起動

**推奨**: プロジェクトルートから Makefile を使用すると便利です。

### 1. 環境変数の設定

```bash
# Makefile を使う場合（推奨）
make infra-setup

# または手動で作成する場合
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
# Makefile を使う場合（推奨）
make infra-up

# または直接 Docker Compose を使う場合（Profileの指定が必要）
cd infrastructure
docker compose --profile weaviate --profile postgresql up -d
```

**初回起動時の自動処理**:

- PostgreSQLコンテナが `n8n_db` データベースを自動作成します
- `init-scripts/01-init-databases.sh` が自動実行されます
- 2回目以降の起動では、既存のデータベースをそのまま使用します

### 3. アクセス

起動完了まで2-3分待機してから：

- **n8n**: http://localhost:5678
- **Dify**: http://localhost:80

## ✅ 動作確認

```bash
# Makefile を使う場合
make infra-ps

# または直接 Docker Compose を使う場合
cd infrastructure
docker compose ps

# 全て "Up (healthy)" になっていればOK
```

## 📊 ステータス確認

### Makefile を使う場合

```bash
make infra-health    # 全サービスのヘルスチェック
make infra-db        # PostgreSQL に接続
make infra-redis     # Redis に接続
```

### 直接確認する場合

| サービス   | 確認方法                                         |
| :--------- | :----------------------------------------------- |
| PostgreSQL | `docker compose exec db psql -U logicfactory -l` |
| Redis      | `docker compose exec redis redis-cli ping`       |
| n8n        | http://localhost:5678/healthz                    |
| Dify       | http://localhost/health                          |

## 🛠 トラブルシューティング

### コンテナが起動しない

```bash
# Makefile を使う場合
make infra-logs      # 全ログ確認
make infra-down      # 停止
make infra-up        # 起動

# または直接使う場合
docker compose logs <service-name>
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
# Makefile を使う場合（警告プロンプト付き）
make infra-clean-all
make infra-up

# または直接使う場合
docker compose down -v
docker compose up -d
```

## 📚 次のステップ

- [詳細なREADME](./README.md) - 全コマンドとトラブルシューティング
- [設計仕様書](./docs/spec.md) - アーキテクチャの詳細
- [n8nドキュメント](https://docs.n8n.io/)
- [Difyドキュメント](https://docs.dify.ai/)
