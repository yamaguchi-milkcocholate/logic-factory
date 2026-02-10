# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Logic Factory は、AI 駆動型マルチプロジェクト基盤であり、以下の3つの哲学に基づいています:

1. **Strategic Prototyping**: 中長期のロードマップを描きつつ、独自の技術ロジックで即座に動く MVP を作る
2. **Environment Architect**: 自分が動かなくても成果が出るパイプラインを設計し、労働の「切り売り」を排す
3. **Truth-Seeking**: 主観や情報の歪みを AI ロジックで正し、客観的事実に基づいた価値を提供する

## システムアーキテクチャ

詳細は[`docs/02_architecture/infrastructure.md`](../docs/02_architecture/infrastructure.md)を参照

## 開発コマンド

### 環境構築・起動

```bash
# 共通基盤（n8n, Dify, PostgreSQL）の起動
cd infrastructure
docker compose up -d

# サービスへのアクセス
# - Dify: http://localhost:80
# - n8n: http://localhost:5678
```

### Python 開発環境

```bash
# uv を使用してパッケージ管理（各 apps/{app_name}/ ディレクトリ内で実行）
uv sync                    # 依存関係のインストール
uv run python main.py      # アプリケーションの実行
uv run ruff check .        # Lint実行
uv run ruff format .       # フォーマット実行
uv run mypy .              # 型チェック実行
```

## コーディング規約

詳細は[`docs/01_guidelines/code.md`](../docs/01_guidelines/code.md)を参照

### 共通基盤利用ルール (docs/01_guidelines/tool.md より)

詳細は[`docs/01_guidelines/tool.md`](../docs/01_guidelines/tool.md)

## 開発プロセス (Spec-Driven Development)

詳細は[`docs/01_guidelines/spec-driven-development.md`](../docs/01_guidelines/spec-driven-development.md)を参照

## インフラストラクチャ設計思想 (docs/02_architecture/infrastructure.md より)

### 基本原則

- **Everything as Code**: `infrastructure/` 配下の設定ファイルのみで環境を完全再現可能
- **Environment Parity**: ローカル (Docker Compose) と本番 (GCP VM/Cloud Run) の差異を最小化

### コンポーネント詳細

**n8n (オーケストレーション)**:

- PostgreSQL を外部 DB として接続（SQLite 非使用）
- 実行ログを DB に保存し、コンテナ再起動時も状態を維持

**Dify (推論エンジン)**:

- マイクロサービス構成: `api` / `worker` / `db` / `redis` / `sandbox`
- `sandbox`: 安全なコード実行環境

**Python Worker (実行エージェント)**:

- ローカルでは同一 Docker 内のコンテナとして稼働
- 高負荷時は `Cloud Run Jobs` へオフロード
- `/shared/data` を全コンテナ間でマウントし、動画素材や解析ログの受け渡しを実現

### ストレージ戦略

| 種類           | 用途           | ローカル                 | GCP                        |
| :------------- | :------------- | :----------------------- | :------------------------- |
| **Structured** | 設定・履歴     | PostgreSQL Container     | Cloud SQL (or VM内DB)      |
| **Cache**      | 一時データ     | Redis Container          | Memorystore (or VM内Redis) |
| **Blob**       | 動画・画像素材 | `./shared/data` (Volume) | Google Cloud Storage       |

### 監視とロギング

- 各コンテナにヘルスチェックを設定し、依存関係を定義
- 全コンテナの標準出力を `logic-factory/logs/` に集約

## 重要な注意事項

- プロジェクト間で共通利用する処理は `shared/python/` に配置し、各アプリから参照
- 各アプリの `pyproject.toml` で依存関係を完全に隔離
- 外部 LLM API のタイムアウトやレートリミットを考慮した防御的プログラミング
- 「なぜこの判断（バイアス判定）をしたか」の推論プロセスをログに残す
