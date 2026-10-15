# backend

タスク管理アプリのバックエンド（Java + Spring Boot）です。REST API を提供します。

プロジェクト全体の概要・起動方法は[ルートの README.md](../README.md) を参照してください。

## 起動

通常は Docker Compose 経由で起動します。

```bash
docker compose up -d   # リポジトリルートで実行 → http://localhost:8080
```

Spring Boot DevTools を入れているため、ソースを変更すると自動で再起動します。

## コマンドの実行はコンテナ内で

Gradle タスクは**必ずコンテナ内で実行してください**。このプロジェクトは Java 25 の toolchain を要求しており、ホスト側のJavaがそれを満たさない場合にビルドが失敗するためです。

```bash
docker exec -w /workspace task-management-backend ./gradlew check
```

通常は個別に叩くのではなく、リポジトリルートの `bash scripts/quality-check.sh` を使ってください（backend/frontend 両方のチェックがこのスクリプト1本に集約されています。詳細は [CONTRIBUTING.md 5章](../CONTRIBUTING.md#5-push前の品質チェック)）。

## パッケージ構成

`com.tkmedia.taskmanagement` 配下を、レイヤードアーキテクチャに沿って分けています。

| パッケージ | 役割 |
| --- | --- |
| `controller` | HTTPリクエストの受け口。URLとメソッドの割り当て、リクエストの検証（`@Valid`）まで |
| `service` | 業務ルールの実装とトランザクション境界。「完了カードのみアーカイブ可」などの判断はここ |
| `repository` | データアクセス（Spring Data JPA）。複雑な絞り込みは `@Query` のJPQLで記述 |
| `entity` | DBのテーブルに対応するJPAエンティティ |
| `dto` | リクエスト／レスポンスの型。エンティティを直接外に出さないための境界 |
| `exception` | 独自例外と、それをHTTPレスポンス（ProblemDetail）へ変換する `@RestControllerAdvice` |
| `config` | CORS設定など、`@Configuration` によるBean定義 |

各層の責務や「なぜそう分けるのか」は [docs/spring-boot/01-architecture.md](../docs/spring-boot/README.md#2-レイヤードアーキテクチャ) で解説しています。

## 設定ファイル

| パス | 内容 |
| --- | --- |
| `src/main/resources/application.properties` | 既定の設定（本番相当の安全側の値） |
| `src/main/resources/application-dev.properties` | 開発用の上書き（Actuatorの詳細表示など）。`SPRING_PROFILES_ACTIVE=dev` で有効 |
| `config/checkstyle/` | Checkstyle（コーディング規約）の設定 |
| `config/spotbugs/` | SpotBugs（バグパターン検出）の除外設定 |

DB接続情報（`DB_URL`・`DB_USERNAME`・`DB_PASSWORD`）は環境変数から注入します。値は Docker Compose が渡します。既定値は `docker-compose.yml` にあり、リポジトリルートに `.env` を作ると、その値で上書きされます（詳しくは[ルートの README](../README.md#設定を変える)）。

## 学習ドキュメント

実装の設計判断や、登場する概念の解説は以下にまとめています。

- [docs/spring-boot/](../docs/spring-boot/README.md) — Spring Boot の使い方（DI・JPA・Repository・DTO・バリデーション・例外処理など）
- [docs/java/](../docs/java/README.md) — Java言語の文法（ジェネリクス・ラムダ式・record・例外処理など）
