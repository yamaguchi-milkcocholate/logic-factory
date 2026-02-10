# Logic Factory 🏭

> **"才能（ロジック）を仕組みとしてパッケージ化し、最小の介在時間で最大の価値を生成する。"**

Logic Factory は、バイアス検知、事実整理、環境構築をデジタル資産として集約・運用するための、AI 駆動型マルチプロジェクト基盤です。

---

## 🏗 システム哲学 (Philosophy)

1. **Strategic Prototyping**: 中長期のロードマップを描きつつ、独自の技術ロジックで即座に動くもの（MVP）を作る。
2. **Environment Architect**: 自分が動かなくても成果が出るパイプラインを設計し、労働の「切り売り」を排す。
3. **Truth-Seeking**: 主観や情報の歪みを AI ロジックで正し、客観的事実に基づいた価値を提供する。

---

## 🛠 共通基盤スタック (Shared Infrastructure)

本リポジトリは、全てのプロジェクトで共通して利用する以下の基盤を `infrastructure/` にて管理します。

- **Orchestrator**: [n8n](https://n8n.io/) (ワークフロー制御、API連携、スケジュール管理)
- **AI/LLM Logic**: [Dify](https://dify.ai/) (プロンプトエンジニアリング、RAG、解析ロジックのAPI化)
- **Database**: PostgreSQL (設定および解析データの永続化)
- **Computing**: Local Docker -> GCP VM (Coolify 運用)
- **Execution**: Cloud Run Jobs (重い Python 処理・動画レンダリングのオンデマンド実行)

---

## 📂 ディレクトリ構造 (Structure)

```text
.
├── infrastructure/          # 共通基盤（n8n, Dify, DB等）の設定
├── apps/                    # 個別プロジェクト（モジュール）
│   └── mediabias-autotube/  # オールドメディア報道の自動バイアス解析
├── shared/                  # プロジェクト間共通の Python ライブラリ / ユーティリティ
├── docs/                    # 共通ガイドライン・システム構成図
└── Makefile                 # 環境構築・運用コマンド
```

---

## 🚀 開発プロセス (Spec-Driven Development)

各プロジェクトの開発は、以下の「SDD サイクル」に従って進行します。

1. **Spec**: `apps/{project}/docs/{spec-name}.md` にて仕様を定義。
2. **Build**: 共通基盤（n8n/Dify）を活用し、ロジックをプロトタイプ化。
3. **Automate**: Python (Cloud Run) 等で重い処理を自動化し、パイプラインを完成させる。
4. **Deploy**: Coolify 経由で GCP VM へ展開し、介在ゼロの運用フェーズへ移行。

---

## 🛠 クイックスタート (Setup)

### 1. 基盤の起動

```bash
cd infrastructure
docker-compose up -d

```

### 2. Dify / n8n へのアクセス

- Dify: `http://localhost:80`
- n8n: `http://localhost:5678`

---

## 📝 規約 (Guidelines)

- **AI Model Selection**: 高度な論理解析には `Claude 3.5 Sonnet`、大量・低コスト処理には `Gemini 1.5 Flash` を優先。
- **Commit Message**: `feat({app_name}): ...` または `fix({app_name}): ...` の形式を推奨。
- **Python**: 全ての独自実装は `shared/` のユーティリティを可能な限り利用し、型ヒントを必須とする。
