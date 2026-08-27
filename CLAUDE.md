# CLAUDE.md

このファイルは、Claude Code と Cursor の両方がこのリポジトリで作業する際に読む、プロジェクト固有のガイドです。

## プロジェクト概要

個人利用向けのタスク管理アプリ（Trelloライクなボード管理）。詳細は [docs/requirements.md](./docs/requirements.md) を参照してください。

- フロントエンド: React + TypeScript
- バックエンド: Java + Spring Boot
- データベース: PostgreSQL

## 開発フロー

**Issue駆動の開発フローは [.claude/rules/issue-driven-workflow.md](./.claude/rules/issue-driven-workflow.md) が正本。** 全プロジェクト共通のルールとして配布されており、毎セッション自動で読み込まれる（Cursor 用は `.cursor/rules/` に同じ内容がある）。ここには重複して書かない。

人が読む運用ドキュメントは [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 品質チェックとフック

push前の品質チェックは**2段構え**になっている。`git push` を検知した hook が、この順で実行する。

| 段 | ファイル | 所有 | 中身 |
| --- | --- | --- | --- |
| ① | `scripts/harness-check.sh` | ハーネス（配布物） | 言語非依存。コンフリクトマーカーの残留・秘匿情報の混入・ブランチ名の規約 |
| ② | `scripts/quality-check.sh` | このプロジェクト | backend（Checkstyle・SpotBugs・既存テスト）・frontend（oxlint・型チェック・ビルド） |

①が落ちた時点で②は走らない。**①は書き換えない**（配布物なので、直すと以後の更新が届かなくなる）。

- **`scripts/quality-check.sh` が②の実処理の唯一の正。** チェック内容はこのスクリプト1本に集約している。個別のコマンドを直接叩くのではなく、必ずこれを呼ぶ
- **CIは「ビルドが通ること」しか見ない。** 静的解析・テストの実行はCIに含まれていないため、push前のこのチェックが唯一の検出機会になる（詳しい経緯は[CONTRIBUTING.md 5章](./CONTRIBUTING.md#5-push前の品質チェック)参照）
- **`.claude/settings.json` を変更したら、Claude Codeの再起動が必要。** hooksはセッション開始時にのみ読み込まれ、動的な変更は反映されない
- 手動で品質チェックしたい場合は `/quality-check` スキルを使う
- backend関連のコマンドは、必ず `docker exec -w /workspace task-management-backend <cmd>` の形でコンテナ内実行する（ホストのJavaは11系で、backendが要求するJava 25 toolchainを満たさないため）

## コーディング規約（コメント）

ユーザーはバックエンド（Spring Boot / Java）の実戦経験が浅く、開発と並行して学習を進めている。生成するコードは以下のルールに従い、実装内容を理解する補助となるコメントを付けること。

1. **スタイルはJavadoc（`/** */`）と行コメント（`//`）を併用する。**
   - クラス・インターフェース・メソッド・フィールドなど、定義の**役割**は直上にJavadocで記載する。
   - 処理内部の**「なぜそう実装するか・どういう仕組みか」**は行コメントで記載する。アノテーションの意味や設計意図も、理解の助けになる箇所には積極的に添える。
2. **対象は実装内容を理解するために必要な箇所すべて。** クラス定義・フィールド・メソッドは代表例であり、これに限らない。ただし**getter/setterのような自明な定型コードは対象外**とする（フィールド側にコメントがあれば意図は伝わるため、機械的な冗長コメントはかえって理解を妨げる）。
3. **トーンは「何を」だけでなく「なぜ」も書く。** `application.properties`や`docker-compose.yml`など、既存の設定ファイルにすでにあるコメント文化（常体・rationaleを書く）を踏襲する。
4. **新規実装だけでなく既存コードも対象。** 新しい概念を含むファイルを追加・変更する際、近傍の未コメントの既存コードに手を入れる場合は、あわせてコメントを補うことが望ましい。
5. コメントは`javac`のコンパイル時にすべて破棄されるため、ビルド成果物（`.class`・JAR）には残らない。除去のための追加設定は不要。

## 学習ドキュメント

ユーザーはバックエンド（Spring Boot / Java）・フロントエンド（React / TypeScript）ともに実戦経験が浅く、開発と並行して学習を進めている。そのため、フレームワーク・言語ごとに学習ドキュメントを整備し、**実装で新しい概念・技術要素が登場したら、都度対応するドキュメント群を更新すること**をルールとする。

- Spring Boot自体の理解を深めるための学習ドキュメントは [docs/spring-boot/](./docs/spring-boot/README.md) に整備している（例：Repository、Service、DTO、バリデーション、例外処理、認証など）。更新方法は[docs/spring-boot/README.mdの更新ルール](./docs/spring-boot/README.md#このドキュメントの更新ルール)を参照。
- Java**言語**自体（本プロジェクトの実装を理解するために必要な範囲に限る）の学習ドキュメントは [docs/java/](./docs/java/README.md) に整備している（例：ジェネリクス、ラムダ式、record、例外処理など）。更新方法は[docs/java/README.mdの更新ルール](./docs/java/README.md#このドキュメントの更新ルール)を参照。
- Reactというライブラリ・周辺ツール（React Router、Vite、Tailwind CSSなど）の使い方の学習ドキュメントは [docs/react/](./docs/react/README.md) に整備している（例：コンポーネント、フック、ルーティング、状態管理など）。更新方法は[docs/react/README.mdの更新ルール](./docs/react/README.md#このドキュメントの更新ルール)を参照。
- TypeScript**言語**自体（本プロジェクトの実装を理解するために必要な範囲に限る。TypeScriptはJavaScriptのスーパーセットのため、必要な範囲のJavaScript構文・ブラウザAPIも含む）の学習ドキュメントは [docs/typescript/](./docs/typescript/README.md) に整備している（例：ジェネリクス、ユニオン型、非同期処理など）。更新方法は[docs/typescript/README.mdの更新ルール](./docs/typescript/README.md#このドキュメントの更新ルール)を参照。
- AWSというクラウドサービス自体（本プロジェクトのデプロイに必要な範囲に限る）の学習ドキュメントは [docs/aws/](./docs/aws/README.md) に整備している（例：ルートユーザーとIAM、アクセスキー、リージョン、課金の仕組みなど）。更新方法は[docs/aws/README.mdの更新ルール](./docs/aws/README.md#このドキュメントの更新ルール)を参照。
- Terraformというツール自体（インフラをコードで記述・構築するための道具）の学習ドキュメントは [docs/terraform/](./docs/terraform/README.md) に整備している（例：IaCの考え方、init/plan/apply、state、バージョン固定など）。更新方法は[docs/terraform/README.mdの更新ルール](./docs/terraform/README.md#このドキュメントの更新ルール)を参照。

フレームワーク・ライブラリの使い方と言語自体の文法のどちらの話か迷ったときは、バックエンドは前者を`docs/spring-boot/`・後者を`docs/java/`に、フロントエンドは前者を`docs/react/`・後者を`docs/typescript/`に書き分ける。同じく、AWSというサービスそのものの知識（各サービスの役割・料金・アカウント運用）は`docs/aws/`に、Terraformというツールの知識（文法・ワークフロー・stateの扱い）は`docs/terraform/`に書き分ける。

## 参考ドキュメント

- [.claude/rules/issue-driven-workflow.md](./.claude/rules/issue-driven-workflow.md) — 開発フローの正本（全プロジェクト共通の配布ルール）
- [CONTRIBUTING.md](./CONTRIBUTING.md) — 開発運用ルール全般（ブランチ命名・PR/マージ手順）。人向け
- [docs/requirements.md](./docs/requirements.md) — 要件定義書（ハブ）
- [docs/spring-boot/README.md](./docs/spring-boot/README.md) — Spring Boot 学習ドキュメント（アーキテクチャ・各ファイルの役割）
- [docs/java/README.md](./docs/java/README.md) — Java言語 学習ドキュメント（本プロジェクトの実装に登場する範囲のJava文法）
- [docs/react/README.md](./docs/react/README.md) — React 学習ドキュメント（コンポーネント・フック・ルーティングなど）
- [docs/typescript/README.md](./docs/typescript/README.md) — TypeScript言語 学習ドキュメント（本プロジェクトの実装に登場する範囲のTypeScript・JavaScript文法）
- [docs/aws/README.md](./docs/aws/README.md) — AWS 学習ドキュメント（アカウント設定・CLI・コスト管理・デプロイ前の宿題）
- [docs/terraform/README.md](./docs/terraform/README.md) — Terraform 学習ドキュメント（IaCの考え方・ワークフロー・state・運用の決めごと）
