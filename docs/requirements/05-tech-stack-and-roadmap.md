# 技術スタック・今後の拡張ロードマップ

[← 要件定義書トップへ戻る](../requirements.md)

> 元の要件定義書における **9章（技術スタック）** と **10章（今後の拡張ロードマップ）** をまとめています。

---

## 9. 技術スタック

技術スタックは以下のとおり確定します。個人利用のMVP・学習用プロジェクトという性格を踏まえ、周辺ツールは最小構成に絞ってコア技術に集中し、各技術は最新のLTS版を採用したうえで、フロントエンド・バックエンド・データベースをそれぞれDockerコンテナとして構築します（バージョン方針は[9.2](#92-バージョン方針)、実行環境は[9.3](#93-実行環境dockerコンテナ構成)を参照）。バックエンドは `trello-research.md` 8章の提案（Node.js／BaaS）を土台に検討した結果、Java + Spring Boot に確定しました。

### 9.1 採用する技術スタック

| 役割 | 採用技術 | 選定理由 |
| --- | --- | --- |
| フロントエンド | React + TypeScript（ビルド：Vite） | 学習情報が豊富で、型のあるコードで開発できる。Vite は Create React App に代わる標準的な高速ビルドツール |
| ルーティング | React Router | ボード詳細／横断ビュー／検索結果／アーカイブなど、複数画面（[6章](./03-screens.md#6-画面構成と画面遷移)）の切り替えを担う |
| スタイリング | Tailwind CSS | ユーティリティクラスで、レスポンシブ対応のUI（[8.1](./02-requirements.md#81-対象デバイス画面サイズ)）を効率よく構築できる |
| ドラッグ＆ドロップ | 既存ライブラリ（`dnd kit`） | カード移動のようなUIを自前実装せず導入でき、タッチ操作にも対応できる（[8.1](./02-requirements.md#81-対象デバイス画面サイズ)） |
| バックエンド | Java + Spring Boot（ビルド：Gradle） | 型安全でREST APIのエコシステム・学習情報が豊富。Gradleは記述が簡潔 |
| データアクセス | Spring Data JPA（Hibernate） | BOARD/CARD/LABELの素直な正規化スキーマ（[7章](./04-data-model.md#7-データモデル)）をO/Rマッピングで扱える |
| データベース | PostgreSQL | リレーショナルDBで、Board/Card/Labelの関係を素直に表現できる。将来的な `user_id` の追加にも対応しやすい（[7.3](./04-data-model.md#73-設計上の補足)・[8.5](./02-requirements.md#85-保守性拡張性)） |
| API方式 | REST（JSON） | フロントエンドとバックエンドを分離した構成における標準的な通信方式 |
| 実行環境 | Docker／Docker Compose | フロントエンド・バックエンド・データベースをそれぞれコンテナ化し、`docker-compose` で連携する（[9.3](#93-実行環境dockerコンテナ構成)参照） |
| 認証（アクセス制限） | ベーシック認証（Webサーバー／リバースプロキシ／ホスティングのパスワード保護機能等） | 本人のみアクセスできればよく実装コストが最小。HTTPS化とあわせて設定する（[8.2](./02-requirements.md#82-認証セキュリティ)） |

フロントエンド（React）とバックエンド（Spring Boot）は分離構成とし、REST API（JSON）で通信します。開発時は両者のオリジン（ポート）が異なるため、Spring Boot側でCORS設定が必要です。認証は[8.2](./02-requirements.md#82-認証セキュリティ)の方針どおりリバースプロキシ／ホスティング層のベーシック認証とし、アプリ本体（画面・データモデル）には手を加えません。

### 9.2 バージョン方針

各技術は、開発着手時点で最新の **LTS（長期サポート）版**を採用することを基本方針とします。LTSの区分を持たない技術（Spring Boot・React・TypeScript・PostgreSQL等）は、サポート期間内の**最新安定版**を採用します。

> 下表のバージョン番号は更新が早く陳腐化しやすいため、あくまで2026年7月時点の参考値です。実装着手時にあらためて最新版を確認してください（[8.1](./02-requirements.md#81-対象デバイス画面サイズ)で対象ブラウザを「latest / latest-1」のように相対表現で書いているのと同じ考え方です）。

| 技術 | サポート区分 | 採用バージョン（2026年7月時点・参考） |
| --- | --- | --- |
| Java | LTS | Java 25（LTS） |
| Node.js（フロントエンドのビルド／実行環境） | Active LTS | Node.js 24（LTS） |
| Spring Boot | 最新安定版（LTS区分なし） | Spring Boot 4.1 |
| React | 最新安定版（LTS区分なし） | React 19系 |
| TypeScript | 最新安定版（LTS区分なし） | TypeScript 6系 |
| PostgreSQL | 最新安定版（メジャーバージョンごとに約5年サポート） | PostgreSQL 18 |

### 9.3 実行環境（Dockerコンテナ構成）

フロントエンド・バックエンド・データベースを、それぞれ独立したDockerコンテナとして構築し、`docker-compose.yml` で一括起動・連携します。

| コンテナ | ベースイメージ例 | 役割 |
| --- | --- | --- |
| frontend | `node:24`（Node.js LTS） | Reactアプリ（Vite）。開発時はdev serverを、本番はビルド成果物を配信する |
| backend | `eclipse-temurin:25-jdk`（Java LTS） | Spring Bootアプリ（REST API） |
| db | `postgres:18` | PostgreSQL。データはボリュームで永続化する |

ベーシック認証（[8.2](./02-requirements.md#82-認証セキュリティ)）は本番デプロイ時に前段のWebサーバー／ホスティング層で設定するものであり、上記3コンテナの構成には含まれません。

> **開発環境と本番環境の構成差について**: 上記は本番相当の構成です。開発環境の `docker-compose.yml` は frontend・backend・db に加え、DBの中身をブラウザから確認するための開発用GUI（CloudBeaver）を含む4サービス構成になっています。本番はサービスごとに `docker build` した単体イメージをデプロイする方針で、backendは本番用の `backend/Dockerfile` を用意済みです（frontendの本番用Dockerfileは今後整備）。本番のDB接続先は、外部／マネージドなPostgresを環境変数（`DB_URL`等）で指す構成を想定しており、具体的な配線は今後の課題とします。

### 9.4 品質チェックツール

開発を進める中で、以下を導入済みです。

| ツール | 役割 |
| --- | --- |
| push前の品質チェック（`scripts/quality-check.sh`） | backendの静的解析・既存テスト、frontendのLint・型チェック・ビルドをまとめて実行する唯一の検出機会。Claude Code 利用時はガードフック（`.claude/hooks/guard.cjs`）が`git push`実行前に自動で呼び出し、失敗するとpushをブロックする（[CONTRIBUTING.md 5章](../../CONTRIBUTING.md#5-push前の品質チェック)参照） |
| GitHub Actions（CI） | PRの作成・更新のたびに、backendのコンパイル・パッケージング、frontendの型チェック・ビルドが通ることのみを確認する。静的解析・テストの実行は含まない（[CONTRIBUTING.md 6章](../../CONTRIBUTING.md#6-ci自動チェック)参照） |
| Bean Validation | リクエストDTO（record）の入力値検証（[9-write-api-validation.md](../spring-boot/09-write-api-validation.md)参照） |
| javac `-Xlint` / Checkstyle / SpotBugs | バックエンドの静的解析。順に「コンパイラ標準の警告」「ソースコードの見落とし検出」「バイトコードレベルのバグ検出」を担う（[02-build-config.md](../spring-boot/02-build-config.md)参照） |
| oxlint | フロントエンドの静的解析（[frontend/.oxlintrc.json](../../frontend/.oxlintrc.json)）。ESLintではなくRust製の高速な代替を採用している |
| JUnit 5 / Mockito | バックエンドのService層・Controller層の自動テスト（`CardServiceTest`・`BoardServiceTest`・`CardControllerTest`等）。Repository層のJPQLクエリやE2E/結合テストは対象外（[12-testing.md](../spring-boot/12-testing.md)参照） |
| Vitest / Testing Library | フロントエンドのコンポーネント・カスタムフックの自動テスト。現状は`CardCreateForm`・`useApi`・`useMutation`・`useDebouncedValue`の4ファイルに限定（[13-frontend-testing.md](../react/13-frontend-testing.md)参照） |

> **フォーマッタ（Prettier・Spotless等）は意図的に導入していません。** 既存コードは学習用の日本語コメントを多く含み書式が既に一貫しているため、一括整形が生む差分の大きさに見合うメリットが薄いと判断しました。

以下は、開発を進める中で必要になった段階であらためて導入を検討します。

- Flyway（DBスキーマのマイグレーション管理）
- 自動テストのさらなる拡充（Repository層のクエリ検証、E2E/結合テストなど。現状はバックエンドのService層・Controller層、フロントエンドは一部のコンポーネント・カスタムフックが中心）

> **現時点のスキーマ管理方式**: Flyway導入前の現段階では、JPAエンティティ（[7章](./04-data-model.md#7-データモデル)のBOARD/CARD/LABEL/CARD_LABEL）を唯一の情報源とし、`spring.jpa.hibernate.ddl-auto=update` でHibernateに開発DBのスキーマを自動生成させています。本番でこの値（`update`）を使うのは意図せぬスキーマ変更の危険があるため非推奨で、Flyway導入時にSQLファイルでスキーマをバージョン管理する方式へ置き換える想定です。

---

## 10. 今後の拡張ロードマップ

[3.2](./01-overview.md#32-スコープ外の機能今回は実装しない) でスコープ外とした機能を、優先度の目安ごとに整理します。あくまで目安であり、実際の着手順は都度検討します。

### 10.1 近い将来（MVPの次のステップ）

- チェックリスト（カード内のサブタスク管理）
- ブラウザ通知（期日が近いカードのリマインド）
- リストの自由な作成・改名（複数人利用や、より柔軟な運用が必要になった場合）

### 10.2 中期的な拡張

- 添付ファイル・カバー画像
- テンプレート機能（よく使うボード構成のひな形化）
- カレンダービュー・タイムライン（ガントチャート）ビュー

### 10.3 長期的な拡張（大きな設計変更を伴うもの）

- アプリ本体へのログイン機能・複数ユーザー対応（現在のベーシック認証からの発展。[8.2](./02-requirements.md#82-認証セキュリティ)、[7.3](./04-data-model.md#73-設計上の補足)参照）
- 担当者・メンバー招待、コメント機能（複数ユーザー対応が前提）
- リアルタイム同期（WebSocket）
- 外部サービス連携（Power-Ups的な拡張機能）
- 自動化ルール（Butlerのような機能）
