# task-management

個人利用向けのタスク管理アプリ（Trelloライクなボード管理）です。
複数のボードにまたがるタスクを「未着手 / 作業中 / 完了」の3列で**横断的に見渡せる**ことを主眼に設計しています。

要件の全体像は [docs/requirements.md](./docs/requirements.md) を参照してください。

## 主な機能

| 機能 | 概要 |
| --- | --- |
| ボード管理 | 用途ごと（仕事・家事など）にボードを作成・改名・削除・並べ替え |
| カード管理 | タイトル・説明・期日・ラベルを持つカードの作成と編集 |
| ステータス変更 | ドラッグ＆ドロップによる列間の移動と、列内の並べ替え（スマートフォンではメニューからの操作にも対応） |
| 横断マージビュー | 全ボードのカードを3列カンバンの中でボード別にグループ化して表示 |
| ラベル | ボード単位で色付きラベルを作成し、1枚のカードに複数付与 |
| 期日の強調表示 | 期限切れ・期限間近を色で警告 |
| アーカイブ | 完了カードを退避し、復元・完全削除が可能 |
| 検索・絞り込み | キーワード（タイトル・説明）とラベル（OR条件）による絞り込み |

## 技術スタック

| 領域 | 採用技術 |
| --- | --- |
| フロントエンド | React 19 / TypeScript 6 / Vite 8 / Tailwind CSS 4 / React Router 8 / dnd-kit |
| バックエンド | Java 25 / Spring Boot 4 / Spring Data JPA (Hibernate) |
| データベース | PostgreSQL 18 |
| 開発環境 | Docker Compose（frontend / backend / db / CloudBeaver の4サービス） |
| 静的解析 | oxlint（frontend）/ Checkstyle・SpotBugs（backend） |

選定理由と今後のロードマップは [docs/requirements/05-tech-stack-and-roadmap.md](./docs/requirements/05-tech-stack-and-roadmap.md) にまとめています。

## 起動方法

Docker と Docker Compose が動作する環境が必要です。**ホストに Java や Node.js を用意する必要はありません**（すべてコンテナ内で完結します）。

```bash
# 1. 環境変数ファイルを用意する（DBの名前・ユーザー・パスワードを設定）
cp .env.example .env

# 2. 全サービスを起動する（初回はイメージのビルドに数分かかります）
docker compose up -d
```

起動後、以下のURLでアクセスできます。

| サービス | URL | 用途 |
| --- | --- | --- |
| フロントエンド | http://localhost:5173 | アプリ本体 |
| バックエンド | http://localhost:8080 | REST API（`/api/...`） |
| CloudBeaver | http://localhost:8978 | ブラウザからDBの中身を確認するためのGUI |

### サンプルデータを投入する

起動直後のデータベースは空です。動作を確認しやすくするため、サンプルのボード・カード・ラベルを投入できます。

```bash
docker compose exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < db/seed/dummy-data.sql
```

**バックエンドが一度起動した後に実行してください。** テーブルを作るのはバックエンド起動時の `spring.jpa.hibernate.ddl-auto=update` であり、このSQLはデータの投入だけを行うためです。テーブルが無い状態で実行すると `relation "board" does not exist` で失敗します。

なお、このSQLは冒頭で既存データを削除するため、**何度実行しても同じ状態になります**（投入し直したいときにそのまま再実行できます）。

```bash
# 停止する
docker compose down

# データベースの中身ごと消してやり直す
docker compose down -v
```

### バックエンドのコマンドを実行する場合

Gradle タスクなどは、ホストではなくコンテナ内で実行してください。本プロジェクトは Java 25 の toolchain を要求するためです。

```bash
docker exec -w /workspace task-management-backend ./gradlew check
```

## AWSへのデプロイ

AWS上に構築する本番環境の構成（EC2 1台 + RDS）はTerraformで定義しており、`infra/` にあります。手順は [infra/README.md](./infra/README.md) を参照してください。

```bash
terraform -chdir=infra plan     # 何が作られるかを確認する
terraform -chdir=infra apply    # インフラを構築する
bash scripts/deploy.sh --all    # アプリを配置する
```

**課金を止める最も確実な方法はリソースを消すことです。** 使い終わったら `terraform -chdir=infra destroy` を実行してください。消し忘れの確認手順も [infra/README.md](./infra/README.md#片付けdestroy) にまとめています。

## 開発の進め方

Issue駆動の開発フローを採用しています。ブランチ命名・PR作成・マージ方針などの運用ルールは [CONTRIBUTING.md](./CONTRIBUTING.md) にまとめています。

push する前には、必ず品質チェックを実行してください。

```bash
bash scripts/quality-check.sh
```

backend（Checkstyle・SpotBugs・テスト）と frontend（oxlint・型チェック・ビルド）のチェックはこのスクリプト1本に集約しています。CIは「ビルドが通ること」しか見ないため、静的解析はこのpush前チェックが唯一の検出機会になります（経緯は [CONTRIBUTING.md 5章](./CONTRIBUTING.md#5-push前の品質チェック)参照）。

## ドキュメント

このリポジトリは、実装と並行して学習ドキュメントを育てる方針を採っています。実装で新しい概念が登場するたびに、対応するドキュメントを更新しています。

| ドキュメント | 内容 |
| --- | --- |
| [docs/requirements.md](./docs/requirements.md) | 要件定義書（ハブ）。機能要件・画面構成・データモデル・技術選定 |
| [docs/spring-boot/](./docs/spring-boot/README.md) | Spring Boot の学習ノート（アーキテクチャ・Repository・DTO・バリデーション・例外処理など） |
| [docs/java/](./docs/java/README.md) | Java言語の学習ノート（本プロジェクトの実装に登場する範囲の文法） |
| [docs/react/](./docs/react/README.md) | React の学習ノート（コンポーネント・フック・ルーティング・ドラッグ＆ドロップなど） |
| [docs/typescript/](./docs/typescript/README.md) | TypeScript言語の学習ノート（ジェネリクス・ユニオン型・非同期処理など） |
| [docs/aws/](./docs/aws/README.md) | AWS の学習ノート（アカウント設定・コスト管理・デプロイ構成） |
| [docs/terraform/](./docs/terraform/README.md) | Terraform の学習ノート（IaC の考え方・state・ワークフロー） |
| [infra/README.md](./infra/README.md) | AWS環境の構築とデプロイの手順書 |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | 開発運用ルール（ブランチ・PR・品質チェック・CI） |
| [CLAUDE.md](./CLAUDE.md) | Claude Code で作業する際のガイド |

## ディレクトリ構成

```
.
├── backend/          Spring Boot アプリケーション（REST API）
├── frontend/         React + TypeScript アプリケーション（SPA）
├── db/seed/          動作確認用のサンプルデータ（手動で投入する）
├── docs/             要件定義書と学習ドキュメント
├── infra/            AWS環境のTerraform構成
├── prototype/        要件確認用のモック（HTML/CSS/JSのみ。本番実装ではありません）
├── prompt-logs/      開発中のやり取りの記録
├── scripts/          品質チェックなどの開発用スクリプト
└── docker-compose.yml
```
