# ビルドとアプリケーション設定

[← 学習ドキュメントトップへ戻る](./README.md)

> 元の学習ドキュメントにおける **6〜9章** をまとめています。

---

## 6. Gradleとは

> **ビルドツールとは？**
> ソースコードのコンパイル、依存ライブラリのダウンロード、テストの実行、実行可能な成果物（JARファイル）の作成といった一連の作業を、コマンド1つで自動化してくれる仕組みです。

本プロジェクトのバックエンドは**Gradle**（Groovy DSLで記述する方式）をビルドツールとして採用しています。JavaのビルドツールにはGradleのほかにMaven（`pom.xml`というXMLで設定を書く方式）もありますが、Gradleは設定をよりプログラムに近い形（DSL）で簡潔に書けることが特徴です。

プロジェクト内には`gradlew` / `gradlew.bat`というファイルがあります。これは**Gradle Wrapper**と呼ばれる仕組みで、開発者のPCにGradle本体がインストールされていなくても、プロジェクトが指定するバージョンのGradle（`gradle/wrapper/gradle-wrapper.properties`で指定。本プロジェクトは9.5.1）を自動でダウンロードして実行してくれます。これにより「自分の環境ではビルドできるが、他の人の環境ではGradleのバージョン違いで失敗する」という事態を防げます。

> **Laravelとの対比**
> 役割としてはComposer（PHPの依存管理ツール）に近い部分がありますが、GradleはJavaソースの**コンパイル**・**テスト実行**・**パッケージング（JAR化）**まで含めた「ビルド」全体を担う点で、守備範囲がより広いツールです。またGradle Wrapperの「バージョンをプロジェクトに固定する」という考え方は、`composer.lock`がインストールするパッケージのバージョンを固定するのと似た発想です。

---

## 7. build.gradle の読み方

`backend/build.gradle`の全文と、各ブロックの意味は以下のとおりです。

```groovy
plugins {
	id 'java'
	id 'checkstyle'
	id 'org.springframework.boot' version '4.1.0'
	id 'io.spring.dependency-management' version '1.1.7'
	id 'com.github.spotbugs' version '6.5.10'
}

group = 'com.tkmedia'
version = '0.0.1-SNAPSHOT'

java {
	toolchain {
		languageVersion = JavaLanguageVersion.of(25)
	}
}

repositories {
	mavenCentral()
}

dependencies {
	developmentOnly 'org.springframework.boot:spring-boot-devtools'
	implementation 'org.springframework.boot:spring-boot-starter-actuator'
	implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
	implementation 'org.springframework.boot:spring-boot-starter-webmvc'
	runtimeOnly 'org.postgresql:postgresql'
	testImplementation 'org.springframework.boot:spring-boot-starter-actuator-test'
	testImplementation 'org.springframework.boot:spring-boot-starter-webmvc-test'
	testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
}

tasks.named('test') {
	useJUnitPlatform()
}
```

| ブロック | 意味 |
| --- | --- |
| `plugins { }` | このビルドに適用する機能拡張（プラグイン）。`java`はJavaのコンパイル機能そのもの、`checkstyle`・`com.github.spotbugs`は静的解析（[43章](#43-静的解析ツールの導入)で解説）、`org.springframework.boot`はSpring Boot用のタスク（`bootRun`・`bootJar`等）を追加し依存バージョンの管理も担う、`io.spring.dependency-management`はSpring Boot対応ライブラリのバージョンを一括管理する機能を追加する |
| `group` / `version` | このプロジェクトの識別名とバージョン。Mavenのartifact座標に相当する |
| `java { toolchain { ... } }` | ビルド・実行に使うJavaのバージョンをプロジェクト単位で固定する設定。ここでは25を指定しているため、開発者のPCにインストールされているJavaのバージョンによらず、Gradleが指定バージョンのJDKを解決して使う |
| `repositories { mavenCentral() }` | 依存ライブラリをダウンロードしてくる先。`mavenCentral()`は最も標準的な公開リポジトリ |
| `dependencies { }` | このプロジェクトが使うライブラリの一覧（詳細は下表） |
| `tasks.named('test') { useJUnitPlatform() }` | `test`タスク（`./gradlew test`）がJUnit 5（JUnit Platform）でテストを実行するように設定する |

**`dependencies`の各行の記法**

| 記法 | 意味 |
| --- | --- |
| `developmentOnly` | 開発時のみクラスパスに含まれる依存。本番のJARには含まれない |
| `implementation` | コンパイル時にも実行時にも必要な依存。最も基本的な指定 |
| `runtimeOnly` | 実行時にのみ必要（コンパイル時にはコードから直接参照しない）依存 |
| `testImplementation` / `testRuntimeOnly` | テストコードのコンパイル・実行時にのみ必要な依存 |

**依存ライブラリ一覧**

| ライブラリ | 役割 |
| --- | --- |
| `spring-boot-devtools` | ソース変更時の自動再起動やLiveReloadなど、開発を効率化する機能一式（[9章](#9-起動から動作確認までの流れ)で解説） |
| `spring-boot-starter-actuator` | アプリケーションの稼働状況を確認するための監視用エンドポイント（`/actuator/health`等）を追加する |
| `spring-boot-starter-data-jpa` | Spring Data JPA（＋Hibernate）を追加し、JPAエンティティ（[10〜15章](./03-entity-jpa.md)）を使えるようにする |
| `spring-boot-starter-webmvc` | REST APIを作るためのWeb MVC機能一式（組み込みTomcat・`@RestController`等）を追加する。Spring Boot 4系での名称で、3系までの`spring-boot-starter-web`に相当する |
| `postgresql` | PostgreSQLに接続するためのJDBCドライバ |
| `spring-boot-starter-actuator-test` / `spring-boot-starter-webmvc-test` | Actuator・Web MVCそれぞれのテスト支援機能 |
| `junit-platform-launcher` | JUnit 5のテストを実行するためのランチャー |

> **補足（Spring Boot 4系特有の点）**：Spring Boot 4 / Hibernate 6では、JDBC接続情報からPostgreSQL用の方言（Dialect）が自動的に判定されるため、以前のバージョンで必要だった`spring.jpa.properties.hibernate.dialect`の明示的な設定は不要になっています。

---

## 8. application.properties の読み方

`backend/src/main/resources/application.properties`は以下のとおりです（このファイル自体にすでに詳しい日本語コメントが付いています）。

```properties
spring.application.name=task-management

# --- データベース接続 ---
# DB認証情報は docker compose 経由で .env から注入される環境変数を参照する。
# ${VAR} は環境変数 VAR を展開するプレースホルダ。compose の environment で
# DB_URL / DB_USERNAME / DB_PASSWORD をコンテナに渡している（値の実体は .env）。
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}

# エンティティ定義とDBスキーマの差分を起動時にHibernateが自動反映する（開発用）。
# 既存テーブルは破壊せず不足分のみ追加するため、postgres-data ボリュームのデータは保持される。
# 本番でこの値(update)を使うのは非推奨（意図せぬスキーマ変更の危険があるため）。
# 将来的にはFlywayでスキーマをSQLとしてバージョン管理する方式に置き換える想定（要件定義9.4）。
spring.jpa.hibernate.ddl-auto=update

# 補足: Spring Boot 4 / Hibernate 6 は JDBC接続から方言(PostgreSQLDialect)を自動判定するため
# spring.jpa.properties.hibernate.dialect の明示は不要。

# /actuator/health の詳細表示レベル。ここ(全環境共通の既定値)は本番を基準に安全側の
# never（{"status":"UP"} のみ）にしておく。always にするとDB接続状況等の詳細が無認証で
# 見えてしまい、攻撃者に内部構成のヒントを与えるため（Secure by Default）。
# こうしておけば、本番デプロイ時にプロファイル指定を忘れても安全側に倒れる。
# 開発中の疎通確認用に always へ上書きする設定は application-dev.properties 側に置く。
management.endpoint.health.show-details=never

# --- JPA / Web の挙動 ---
# Open Session In View（既定で有効）は、Controllerがレスポンスを返し終えるまでDB接続と
# 永続化コンテキストを保持し続ける仕組み。これが有効だと、Serviceを抜けたあとの
# JSON変換処理の中でも遅延読み込み(LAZY)が"こっそり"成功してしまい、
# 気づかないうちにN+1問題（一覧のループのたびに追加SQLが発行される状態）を招きやすい。
# 本プロジェクトはService層のトランザクション内でDTOへの詰め替えまで完了させる方針のため
# OSIVは不要であり、無効化することで「トランザクションの外で遅延読み込みに触れたら
# 例外になる」状態にし、事故を静かなN+1ではなく気づけるエラーとして検出できるようにする。
spring.jpa.open-in-view=false

# Spring MVCが自前で処理する例外（存在しないパラメータ型など）のレスポンスも、
# RFC 9457（Problem Details for HTTP APIs）形式のJSON（Content-Type: application/problem+json）
# に統一する。自前の例外ハンドラ（GlobalExceptionHandler）が返す404と形が揃うことで、
# クライアント側のエラー処理を1本化できる。
spring.mvc.problemdetails.enabled=true
```

ここでは、ファイル内のコメントで触れられている用語を補足します。

- **`${DB_URL}`のようなプレースホルダ**：`application.properties`は、OSの環境変数を`${変数名}`の形で埋め込めます。本プロジェクトでは、ルートの`docker-compose.yml`が`.env`の値を読み取り、`backend`コンテナに環境変数として渡し、それをこのファイルが参照する、という流れになっています。
- **`spring.jpa.hibernate.ddl-auto=update`**：Hibernateに「エンティティクラスの定義を正としてDBスキーマを自動的に作る／更新する」よう指示する設定です。開発中は手軽ですが、本番運用では意図しないカラム変更が起きうるため非推奨とされ、将来的にはFlyway（SQLファイルでスキーマ変更を管理するマイグレーションツール）に置き換える計画です（[要件定義9.4](../requirements/05-tech-stack-and-roadmap.md#94-品質チェックツール)）。
- **`management.endpoint.health.show-details=never`**：`spring-boot-starter-actuator`が提供する`/actuator/health`エンドポイントの詳細表示レベルの設定です。`never`は`{"status":"UP"}`のみを返す最も安全な既定値で、全環境共通の設定としてあえてこれを明示しています。開発中にDB接続状況などの詳細を見たい場合は、環境ごとにプロファイルを分けて上書きします（[16章](./04-profiles.md#16-環境ごとの設定切り替えプロファイル)で解説）。
- **`spring.jpa.open-in-view=false`**：Repository・Service・Controllerを実装した際（[17〜23章](./05-repository.md)）に追加した設定です。詳しい経緯は[25章](./07-jpa-performance.md#25-open-in-viewと遅延読み込みの境界)を参照してください。
- **`spring.mvc.problemdetails.enabled=true`**：例外処理を実装した際（[23章](./06-service-controller.md#23-例外処理とrestcontrolleradvice)）に追加した設定です。自前の`@RestControllerAdvice`が返す404と、Spring MVCが自前で処理する400などのエラー形式を統一します。

`application.properties`にはこのように「なぜこの設定にしたか」までコメントを残す文化がすでにあります。Javaのソースコードにコメントを書く際も、このトーン（何を、だけでなく、なぜ）を踏襲します（[CLAUDE.mdのコーディング規約](../../CLAUDE.md#コーディング規約コメント)）。

---

## 9. 起動から動作確認までの流れ

ローカルでの起動方法は主に2通りあります。

1. **Gradle単体で起動**：`backend`ディレクトリで`./gradlew bootRun`を実行すると、コンパイル後にアプリケーションが起動し、`http://localhost:8080`で待ち受けを開始します。
2. **docker composeで起動**：プロジェクトルートで`docker compose up --build`を実行すると、`backend`・`db`・`cloudbeaver`の3コンテナが起動します。開発用の`Dockerfile.dev`では、`spring-boot-devtools`（[7章](#7-buildgradle-の読み方)）を活かすため、`./gradlew -t classes`（ソース変更を監視し続けて自動コンパイルする継続ビルド）と`./gradlew bootRun`を同時に動かし、ソースを保存するとアプリが自動的に再起動される仕組みになっています。

いずれの方法でも、起動後に`curl http://localhost:8080/actuator/health`を叩くと、[8章](#8-applicationproperties-の読み方)で解説したActuatorの設定により、DB接続を含めた稼働状況をJSONで確認できます。

なお、DockerやDocker Composeそのものの仕組み（コンテナ・イメージ・volumeなど）は本ドキュメントの対象外です。ここでは「Spring Bootアプリケーションがどう起動するか」に絞って解説しています。

### 動作確認用のダミーデータ投入

Repository・Service・Controller（[17〜23章](./05-repository.md)）の実装後、フロントエンドがまだ無い状態でAPIの動作確認を行うため、`db/seed/dummy-data.sql`（リポジトリルート）にダミーデータ投入用のSQLを用意しています。`TRUNCATE`してから`INSERT`し直す内容になっており、**何度実行しても同じ結果になる**（冪等）ため、動作確認のやり直しがいつでもできます。

```bash
# リポジトリルートで実行。db サービスは5432番ポートをホストに公開していないため、
# コンテナ内のpsqlを使う（sh -c で包むことで、compose が渡した環境変数 POSTGRES_USER /
# POSTGRES_DB をコンテナ側でそのまま展開できる）。
docker compose exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < db/seed/dummy-data.sql
```

このSQLは`board`/`card`/`label`/`card_label`の4テーブルへのINSERTのみを行うDML（データ操作言語）です。テーブル自体は`ddl-auto=update`（[8章](#8-applicationproperties-の読み方)）によってアプリ起動時に作られるため、**必ずbackendを一度起動した後に**実行する必要があります。

### curlによるエンドポイントの動作確認

ダミーデータ投入後、各エンドポイント（[21章](./06-service-controller.md#21-controller層とrest-api)のエンドポイント一覧）に対してcurlでリクエストを送り、レスポンスを確認します。

```bash
# ボード一覧
curl -s http://localhost:8080/api/boards | jq

# カード一覧（絞り込み例：ボード指定 + キーワード + ラベル指定を組み合わせ）
curl -s 'http://localhost:8080/api/cards?boardId=1&keyword=見積&labelIds=1' | jq

# 存在しないIDを指定した場合は404（RFC 9457のProblemDetail形式。23章参照）
curl -s -i http://localhost:8080/api/boards/999
```

開発環境では`logging.level.org.hibernate.SQL=debug`（[16章](./04-profiles.md#16-環境ごとの設定切り替えプロファイル)と同様、`application-dev.properties`限定の設定）によりSQLログが出力されるため、`docker compose logs -f backend`で追いながらリクエストを送ると、実際に発行されているSQLの本数・内容を確認できます。これはN+1問題（[24章](./07-jpa-performance.md#24-n1問題とその回避)）が起きていないことの実地確認として重要です。

---

## 43. 静的解析ツールの導入

これまでの章で実装したAPIが一通り揃った段階で、**コンパイルが通ることと「動くこと」だけでは見落とす類の問題**（未使用のimport、nullになり得る値への注意不足など）を機械的に検出するため、3種類の静的解析を`build.gradle`へ追加しました。いずれも既存コードの書式（インデント幅など）には踏み込まない、「実質的な誤り・見落とし」だけを検出する構成にしています。フォーマッタ（Prettier/Spotless相当）は導入していません。理由は[要件定義9.4](../requirements/05-tech-stack-and-roadmap.md#94-品質チェックツール)を参照してください。

### 43.1 `-Xlint:all`（javac標準の追加警告）

```groovy
tasks.withType(JavaCompile).configureEach {
	options.compilerArgs << '-Xlint:all'
}
```

`javac`自体が持つ追加警告をすべて有効にする設定です。外部ライブラリを追加する必要がなく、コンパイルのたびに実行されるため、3つの中で最も手軽に導入できます。実行してみると、本プロジェクトの現状では次の4件が検出されました（未対応。品質チェックの結果として別Issueで管理する方針としています）。

| 警告の種類 | 検出箇所 | 内容 |
| --- | --- | --- |
| `[serial]` | `ResourceNotFoundException` / `InvalidRequestException` / `CardLabelId` | `Serializable`を実装・継承しているクラスに`serialVersionUID`が定義されていない |
| `[deprecation]` | `Card`エンティティの`@Check`アノテーション | `org.hibernate.annotations.Check`がHibernateの新しいバージョンで非推奨になっている |

`-Werror`（警告をエラー扱いにしてビルドを失敗させる設定）は付けていません。上記の警告が残ったままだと`./gradlew build`自体が通らなくなってしまうためです。

### 43.2 SpotBugs（bytecodeレベルのバグ検出）

```groovy
spotbugs {
	toolVersion = '4.10.3'
	effort.set(com.github.spotbugs.snom.Effort.valueOf('MAX'))
	reportLevel.set(com.github.spotbugs.snom.Confidence.valueOf('DEFAULT'))
	excludeFilter = file('config/spotbugs/exclude.xml')
}
```

Checkstyleが**ソースコードの文字列**を見て検査するのに対し、SpotBugsは**コンパイル後のbytecode**を解析します。そのため、ソースだけを見ていては気づきにくい「実行時にNullPointerExceptionを起こしうる箇所」のような、より実質的なバグ検出が得意です。

> **`effort.set(...)` / `reportLevel.set(...)`という書き方について**：SpotBugs Gradle Pluginの`effort`・`reportLevel`は文字列（`'max'`など）を代入する書き方もできますが、Gradle 10で廃止予定の非推奨機能（文字列→enum定数への暗黙変換）に依存してしまうため、ここでは`Effort.valueOf('MAX')`のようにenum定数を明示的に取得してから`.set()`で渡しています。

導入時、実際にJava 25（class file version 69）のbytecodeを解析できるかを検証しました。結果、`EI_EXPOSE_REP` / `EI_EXPOSE_REP2`（「getter/setter/コンストラクタがミュータブルなフィールドをそのまま受け渡ししている」ことへの指摘）が21件検出されましたが、いずれもJPAエンティティの`@ManyToOne`関連やDTOの`record`という、本プロジェクトの設計上ごく普通のパターンでした。防御的コピーを加えると設計がかえって複雑になるため、`config/spotbugs/exclude.xml`で除外しています（除外の理由はそのファイル自身のコメントに詳しく書いています）。この2つを除外した状態では、他の指摘は0件でした。

レポートは`backend/build/reports/spotbugs/main.html`（HTML形式、人が読みやすい）に出力されます。

### 43.3 Checkstyle（ソースコードの見落とし検出）

```groovy
checkstyle {
	toolVersion = '13.9.0'
	sourceSets = [sourceSets.main]
}
```

検査項目は`backend/config/checkstyle/checkstyle.xml`で定義しています。Checkstyleの配布物にはGoogle/Sunの既定ルールセット（`google_checks.xml`・`sun_checks.xml`）が同梱されていますが、それらはインデント幅・命名規則など**書式**に踏み込む項目を大量に含んでおり、本プロジェクトが採用しているタブインデントと衝突するため採用していません。代わりに、書式に関係しない項目だけを個別に選んでいます。

| 検査項目 | 検出する内容 |
| --- | --- |
| `UnusedImports` | 使われていないimport文 |
| `RedundantImport` | 重複・不要なimport文 |
| `EqualsHashCode` | `equals()`だけ（または`hashCode()`だけ）をオーバーライドしている |
| `MissingSwitchDefault` | switch文に`default`節が無い |
| `FallThrough` | switch文のcaseからのフォールスルー（`break`忘れ） |
| `SimplifyBooleanExpression` | `if (a == true)`のような冗長なboolean比較 |
| `EmptyBlock` | 中身が空のブロック（catch節の握りつぶし等） |
| `NeedBraces` | if/for/while等で波括弧を省略した1行記法 |
| `StringLiteralEquality` | `==`/`!=`による文字列比較（本来`equals()`を使うべき箇所） |
| `IllegalImport` | `javax.*`パッケージ、および`jakarta.transaction.Transactional`のimport。後者は[20章](./06-service-controller.md#20-service層とtransactional)・`BoardService`のクラスコメントで触れている「`readOnly`属性を持たない、よく似た別のアノテーション」で、間違えてもコンパイルは通ってしまう落とし穴のため機械的に検出する |

テストコード（`src/test`）は対象外にしています（現状`TaskManagementApplicationTests`という空のスモークテストのみで、検査から得られる価値が薄いため）。

### 43.4 実行方法

```bash
# 3つすべて（+コンパイル+既存テスト）をまとめて実行
./gradlew check

# 個別に実行したい場合
./gradlew checkstyleMain
./gradlew spotbugsMain
```

**これらはCIでは実行されません。** [CONTRIBUTING.md 5章](../../CONTRIBUTING.md#5-push前の品質チェック)の方針により、push前のローカルチェック（`scripts/quality-check.sh`。Claude Code 利用時はガードフック（`.claude/hooks/guard.cjs`）が`git push`実行前に自動で呼び出す）として実行されます。GitHub Actions CI（[6章](../../CONTRIBUTING.md#6-ci自動チェック)）はコンパイルとパッケージングが通ることのみを確認し、静的解析は行いません。PRを作成した「後」にしか走らないCIより、push前に問題を検出する方を主たる品質ゲートに据えているためです。

---

## 環境情報まとめ

| 項目 | バージョン |
| --- | --- |
| Java | 25 |
| Spring Boot | 4.1.0 |
| Gradle | 9.5.1 |

*上記は2026年7月時点の本プロジェクトの構成です。[要件定義9.2](../requirements/05-tech-stack-and-roadmap.md#92-バージョン方針)のとおり、バージョンは今後更新される可能性があります。*
