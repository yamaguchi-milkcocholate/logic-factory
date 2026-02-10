# {CHANGE_ID} - 変更設計書

> 対象プロジェクト: {PROJECT_NAME}
> 作成日: {DATE}

## 1. 変更の概要

### 目的

{PURPOSE}

### 影響範囲

- [ ] n8n ワークフロー
- [ ] Dify プロンプト/ワークフロー
- [ ] Python スクリプト (`apps/{PROJECT_NAME}/src/`)
- [ ] インフラ設定 (`infrastructure/`)
- [ ] 共通基盤 (`shared/`)
- [ ] ドキュメント

---

## 2. 変更内容

### 変更するファイル

| ファイルパス | 変更内容 | 理由 |
| :----------- | :------- | :--- |
| {FILE_PATH}  | {CHANGE} | {REASON} |

### 追加するファイル（あれば）

| ファイルパス | 目的 |
| :----------- | :--- |
| {FILE_PATH}  | {PURPOSE} |

---

## 3. 実装詳細

### 変更のポイント

{IMPLEMENTATION_DETAILS}

### 考慮事項

- **後方互換性**: {BACKWARD_COMPATIBILITY}
- **エラーハンドリング**: {ERROR_HANDLING}
- **ログ出力**: {LOGGING}
- **パフォーマンス**: {PERFORMANCE}

---

## 4. テスト計画

### テストケース

- [ ] {TEST_CASE_1}
- [ ] {TEST_CASE_2}
- [ ] エラーケースの確認

### 確認項目

- [ ] ローカル環境での動作確認
- [ ] 既存機能への影響がないこと
- [ ] ログが適切に出力されること
- [ ] エラー時の挙動が適切であること

---

## 5. デプロイ手順

### 事前準備

{PREREQUISITES}

### デプロイ手順

1. {STEP_1}
2. {STEP_2}
3. {STEP_3}

### ロールバック手順（必要な場合）

{ROLLBACK_PROCEDURE}

---

## 6. Notes

### 技術的な注意事項

- {TECHNICAL_NOTES}

### 将来的な改善案

- {FUTURE_IMPROVEMENTS}

---

## Appendix

### 関連資料

- [メインプロジェクト仕様書](../spec.md)
- [Python Coding Standards](../../../docs/01_guidelines/code.md)
- [Spec-Driven Development](../../../docs/01_guidelines/spec-driven-development.md)
