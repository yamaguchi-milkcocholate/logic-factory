# Logic Factory Infrastructure Specification

## 1. インフラ基本思想

- **Everything as Code**: 全てのインフラ定義をコード化し、`infrastructure/` 配下の設定ファイルのみで環境を完全再現可能とする。
- **Environment Parity**: ローカル (Docker Compose) と本番 (GCP VM/Cloud Run) の差異を最小化し、環境依存のバグを排除する。

## 2. ネットワークトポロジー

全てのサービスは Docker 内のカスタムブリッジネットワーク `logic-factory-net` に参加し、サービス名による名前解決（DNS）を行う。

- **Internal (Private)**: DB、Redis、Dify API は外部公開せず、n8n や Worker からのみアクセスを許可。
- **External (Public)**: n8n の UI (ポート 5678) および Dify UI (ポート 80) のみ、リバースプロキシ経由で外部公開。

## 3. コンポーネント詳細

### A. オーケストレーション (n8n)

- **Persistance**: SQLite ではなく PostgreSQL を外部 DB として接続。
- **Isolation**: 実行ログを DB に保存し、コンテナが再起動してもワークフローの状態を維持。

### B. 推論エンジン (Dify)

- **Modular Stack**: 以下のマイクロサービス群で構成。
  - `api` / `worker`: 推論実行エンジン。
  - `db`: Dify 固有の設定・プロンプト管理用。
  - `redis`: キャッシュおよびキュー管理。
  - `sandbox`: 安全なコード実行環境。

### C. 実行エージェント (Python Worker)

- **Compute**: ローカルでは同一 Docker 内のコンテナとして稼働。高負荷時は `Cloud Run Jobs` へオフロード。
- **Volume Mounting**: `/shared/data` をホストおよび全コンテナ間でマウントし、動画素材や解析ログの高速な受け渡しを実現。

## 4. ストレージ戦略

| 種類           | 用途           | 物理実体 (Local)         | 物理実体 (GCP)             |
| :------------- | :------------- | :----------------------- | :------------------------- |
| **Structured** | 設定・履歴     | PostgreSQL Container     | Cloud SQL (or VM内DB)      |
| **Cache**      | 一時データ     | Redis Container          | Memorystore (or VM内Redis) |
| **Blob**       | 動画・画像素材 | `./shared/data` (Volume) | Google Cloud Storage       |

## 5. 監視とロギング (Observability)

- **Health Check**: 各コンテナにヘルスチェックを設定し、n8n が Dify の生存を確認してからワークフローを開始する依存関係を定義。
- **Log Aggregation**: 全コンテナの標準出力を `logic-factory/logs/` に集約し、トラブルシューティングを容易にする。
