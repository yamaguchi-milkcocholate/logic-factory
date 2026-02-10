# Logic Factory Infrastructure

Logic Factory のローカル開発環境（n8n + Dify + PostgreSQL + Redis）を Docker Compose で構築します。

## 前提条件

- Docker Engine 20.10+
- Docker Compose 2.0+

## クイックスタート

### 1. 環境変数の設定

`.env.example` をコピーして `.env` を作成し、必要に応じて値を変更してください。

```bash
cp .env.example .env
```

**重要**: 本番環境では以下の値を必ず変更してください：
- `POSTGRES_PASSWORD`
- `DIFY_SECRET_KEY` (32文字以上のランダム文字列)
- `REDIS_PASSWORD`
- `DIFY_API_KEY` (使用するLLMプロバイダーのAPIキー)

### 2. 環境の起動

```bash
cd infrastructure
docker-compose up -d
```

### 3. 起動確認

全コンテナのステータスを確認：

```bash
docker-compose ps
```

全てのコンテナが `Up (healthy)` になるまで待ちます（初回起動時は2-3分程度）。

### 4. アクセス

- **n8n UI**: http://localhost:5678
- **Dify UI**: http://localhost:80

初回アクセス時にセットアップウィザードが表示されます。

## サービス構成

| サービス | 役割 | ポート |
|:---------|:-----|:-------|
| n8n | ワークフローオーケストレーション | 5678 |
| dify-web + nginx | AI推論エンジン UI | 80 |
| dify-api | Dify APIサーバー | - (内部) |
| dify-worker | バックグラウンドジョブ実行 | - (内部) |
| dify-sandbox | コード実行サンドボックス | - (内部) |
| db (postgres) | データベース | - (内部) |
| redis | キャッシュ/キュー | - (内部) |

## よく使うコマンド

### ログの確認

```bash
# 全コンテナのログ
docker-compose logs -f

# 特定サービスのログ
docker-compose logs -f n8n
docker-compose logs -f dify-api

# エラーログのみ
docker-compose logs | grep ERROR
```

### 環境の停止

```bash
# コンテナを停止（データは保持）
docker-compose stop

# コンテナを停止して削除（データは保持）
docker-compose down

# 全てを削除（データも削除）
docker-compose down -v
```

### 環境の再起動

```bash
docker-compose restart
```

### 特定サービスの再起動

```bash
docker-compose restart n8n
docker-compose restart dify-api
```

## トラブルシューティング

### コンテナが起動しない

1. ログを確認：
   ```bash
   docker-compose logs <service-name>
   ```

2. ヘルスチェックのステータスを確認：
   ```bash
   docker-compose ps
   ```

3. 全てを停止して再起動：
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### PostgreSQL接続エラー

- データベースが初期化されているか確認：
  ```bash
  docker-compose exec db psql -U logicfactory -l
  ```

- n8n_db と dify_db が存在することを確認

### ポート競合エラー

既に使用されているポートがある場合、`docker-compose.yml` の `ports` セクションを変更：

```yaml
ports:
  - "5679:5678"  # 例: n8nのポートを5679に変更
```

### データの永続化確認

Named Volume の確認：

```bash
docker volume ls | grep logic-factory
```

以下が表示されるはずです：
- `infrastructure_postgres-data`
- `infrastructure_redis-data`
- `infrastructure_n8n-data`

### データベースのリセット

**警告**: 全てのデータが削除されます

```bash
docker-compose down -v
docker volume rm infrastructure_postgres-data infrastructure_redis-data infrastructure_n8n-data
docker-compose up -d
```

## ディレクトリ構造

```
infrastructure/
├── docker-compose.yml       # サービス定義
├── .env                     # 環境変数（gitignore対象）
├── .env.example             # 環境変数テンプレート
├── .gitignore               # Git除外設定
├── README.md                # 本ファイル
├── init-scripts/            # PostgreSQL初期化スクリプト
│   └── 01-init-databases.sql
├── nginx/                   # Nginx設定
│   ├── nginx.conf
│   └── conf.d/
│       └── dify.conf
├── shared/
│   └── data/                # コンテナ間共有ストレージ
├── dify/
│   └── storage/             # Dify生成コンテンツ
└── logs/                    # ログ集約先（オプション）
```

## n8n と Dify の連携

n8n から Dify API を呼び出す際は、以下の URL を使用：

```
http://dify-api:5001
```

Docker ネットワーク内では、サービス名（`dify-api`）で名前解決されます。

## 参照ドキュメント

- [Infrastructure Specification](./docs/spec.md) - 詳細な設計仕様
- [Logic Factory Architecture](../docs/02_architecture/infrastructure.md) - アーキテクチャ概要
- [n8n Documentation](https://docs.n8n.io/)
- [Dify Documentation](https://docs.dify.ai/)
