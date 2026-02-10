# Spec-Driven Development (SDD) Protocol

Logic Factory における開発は、実装（コード）に先立ち、厳密な仕様（スペック）を定義することを絶対原則とする。これにより、AIアシスタントとの協働精度を最大化し、手戻りを最小化（省エネ）する。

---

## 🔄 SDD ライフサイクル詳細

### Phase 1: Spec (定義)

- **Output**: `apps/{project}/docs/{spec-name}.md`
- **Action**:
  - 山口の「才能（ロジック）」を言語化し、入出力、成功定義、バイアス判定基準を明文化する。
  - Claude Code 等に対し「この spec.md を正として、以降の実装を行え」と命じるための「正解データ」を作成する。
- **Checkpoint**: 「この仕様書だけで、背景を知らないエンジニア（またはAI）が実装を開始できるか？」

### Phase 2: Build & Prototype (推論構築)

- **Output**: Dify Workflow / n8n Initial Flow
- **Action**:
  - Dify を用い、LLM のプロンプトエンジニアリングに集中する。
  - n8n で外部 API との接続を確認し、データの疎通を確認する。
  - **No Coding Principle**: この段階では Python コードを書かず、ノーコード/ローコードでロジックの実現可能性を検証する。

### Phase 3: Automate & Solidify (自動化・堅牢化)

- **Output**: Python Scripts (`src/`), Cloud Run Jobs Configuration
- **Action**:
  - `shared/python/` の規約に従い、定型処理や重い処理（動画生成等）を Python で実装。
  - `pydantic` による厳密なデータバリデーションを実装し、パイプラインの信頼性を高める。
  - n8n から Python スクリプトを呼び出すインターフェース（API/Webhook）を確定させる。

### Phase 4: Deploy & Forget (展開・非介在化)

- **Output**: Coolify Deployment, Cloud Scheduler Settings
- **Action**:
  - Coolify を通じて GCP VM へデプロイ。
  - Cloud Scheduler による定期実行を設定し、「人間が触らなくても価値が生まれる状態」へ移行。
- **Monitoring**: n8n のエラー通知フローを有効化し、例外発生時のみ山口が介在する体制を構築。

---

## 🛠 AI協働ガイドライン (AI-Agentic Workflow)

AIアシスタント（Claude Code / Cursor）を「Logic Factory 工員」として機能させるための指示要領。

1. **Context Loading**:
   実装開始前に必ず [`docs/01_guidelines/`](../01_guidelines/) と [`docs/02_architecture/`](../02_architecture/) を読み込ませ、「Logic Factory の規約」を遵守させる。
2. **Spec First**:
   「いきなりコードを書かず、まずは `.md`の設計書 に基づいた実装計画（Plan）を提示せよ」と指示する。
3. **Atomic Implementation**:
   大規模な実装は避け、spec 内のタスク単位でインクリメンタルに実装・テストを繰り返させる。

---

## 📏 仕様書の必須項目 (spec.md Template)

各プロジェクトの `.md`の設計書 は以下の項目を網羅しなければならない。

- **Project Vision**: 何を解決し、どのような価値（バイアス検知等）を提供するか。
- **Input/Output**: 扱うデータの形式、ソース、出力先。
- **Logic Definition**:
  - 解析フェーズ（Dify）: 判定基準、スコアリングロジック。
  - 実行フェーズ（Python）: アルゴリズム、使用ライブラリ。
- **Infrastructure**: 使用する共通基盤のノード、GCP の特定リソース。
- **Definition of Done (DoD)**: どのような状態になれば「完成（非介在運用可能）」と見なすか。
