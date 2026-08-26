# JPAエンティティ

[← 学習ドキュメントトップへ戻る](./README.md)

> 元の学習ドキュメントにおける **10〜15章** をまとめています。

---

## 10. JPA・Hibernate・ORMとは

> **ORM（Object-Relational Mapping）とは？**
> データベースのテーブルの1行を、Javaのオブジェクト（インスタンス）として扱えるようにする技術です。SQLを直接書かなくても、Javaのコードでデータの読み書きができるようになります。

本プロジェクトでは、次の3つの用語が登場します。

| 用語 | 位置づけ |
| --- | --- |
| **JPA**（Jakarta Persistence API） | Java標準の「ORMの仕様（インターフェース）」。具体的な実装は持たない |
| **Hibernate** | JPAという仕様を実際に実装したライブラリ。本プロジェクトが実際に使っているORM本体 |
| **Spring Data JPA** | Hibernateをさらに使いやすくするSpringの層。Repositoryインターフェースを定義するだけでSQL相当の処理が使えるようになる（Repository実装時に別途詳しく解説予定） |

エンティティクラス（`@Entity`が付いたクラス）は、このORMが「テーブルの1行」として扱うためのクラスです。本プロジェクトには現在5つのエンティティがあります。

| エンティティ | 対応テーブル | 役割 |
| --- | --- | --- |
| `Board` | `board` | ボード（カードを束ねる単位） |
| `Card` | `card` | カード（タスク1件） |
| `Label` | `label` | ラベル |
| `CardLabel` | `card_label` | カードとラベルの中間テーブル（多対多の関連） |
| `CardLabelId` | （`card_label`の複合主キー部分） | `CardLabel`の主キーを表す補助クラス |

> **Laravelとの対比**
> LaravelのEloquent ORMと役割は同じですが、大きな違いがあります。Eloquentのモデルは動的型付け言語であるPHPの特性を活かし、`$model->name`のようにDBのカラム名をその場で（マジックメソッド経由で）扱えます。一方JPAのエンティティは、静的型付け言語であるJavaの特性上、**カラム1つ1つをフィールドとして明示的に、型付きで宣言**します。手間は増えますが、コンパイル時に「存在しないカラムを参照している」といった間違いを検出しやすくなります。

---

## 11. エンティティの基本アノテーション

最もシンプルな`Board`エンティティを教材にします。

```java
@Entity
@Table(name = "board")
public class Board {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Integer id;

	@Column(nullable = false)
	private String name;

	@Column(nullable = false)
	private Integer position;

	@Column(name = "created_at", nullable = false)
	@ColumnDefault("now()")
	private OffsetDateTime createdAt;

	// getter/setterは省略
}
```

| アノテーション | 意味 |
| --- | --- |
| `@Entity` | このクラスがJPAの管理対象（＝DBテーブルに対応するクラス）であることを示す |
| `@Table(name = "board")` | 対応するテーブル名を明示する。省略した場合はクラス名から推測されるが、本プロジェクトでは常に明示している |
| `@Id` | このフィールドが主キーであることを示す |
| `@GeneratedValue(strategy = GenerationType.IDENTITY)` | 主キーの採番方法の指定。`IDENTITY`はDB側（PostgreSQLの自動採番カラム）に採番を委ねる方式で、INSERT時にDBが自動的にIDを払い出す |
| `@Column(nullable = false)` | このカラムがNOT NULL制約（空を許さない）であることを示す |
| `@Column(name = "created_at", ...)` | Javaのフィールド名（`createdAt`）とDBのカラム名（`created_at`）が異なる場合に対応関係を明示する。Javaはキャメルケース、DBはスネークケースという命名慣習の違いを埋めている |
| `@ColumnDefault("now()")` | DB側のDEFAULT句に対応する値。`ddl-auto=update`（[8章](./02-build-config.md#8-applicationproperties-の読み方)）でHibernateがテーブルを生成・更新する際、このデフォルト値がDDLに反映される |

**getter/setterについて**：JPA（Hibernate）はフィールドに`getXxx()`/`setXxx()`という命名のメソッド（JavaBeans規約）を通じてアクセスすることを前提にしている場合があるため、全フィールドに対してgetter/setterを用意しています。本プロジェクトではLombok（`@Getter`/`@Setter`等でgetter/setterを自動生成するライブラリ）を導入していないため、現時点ではすべて手書きです。

---

## 12. リレーション（関連）の書き方

テーブル間の関連（外部キー）は、`Card`エンティティの`board`フィールドのように表現します。

```java
@Entity
@Table(name = "card")
@Check(constraints = "status in ('todo', 'doing', 'done')")
public class Card {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Integer id;

	@ManyToOne(optional = false, fetch = FetchType.LAZY)
	@JoinColumn(name = "board_id", nullable = false)
	@OnDelete(action = OnDeleteAction.CASCADE)
	private Board board;

	// ...他のフィールドは省略
}
```

| アノテーション | 意味 |
| --- | --- |
| `@ManyToOne` | 「多対一」の関連であることを示す。ここでは「複数のCardが1つのBoardに属する」という関係を表す |
| `optional = false` | このBoardへの関連が必須（NULLを許さない）であることを示す |
| `fetch = FetchType.LAZY` | 関連先（Board）の実データを、実際に`card.getBoard()`等でアクセスするまでSQLで取得しない「遅延読み込み」を指定する。常に一括取得（`EAGER`）すると不要なJOINが増えパフォーマンスが落ちるため、明示的にLAZYを指定するのが一般的 |
| `@JoinColumn(name = "board_id", nullable = false)` | この関連を表す外部キーカラムの名前（`board_id`）とNOT NULL制約を指定する |
| `@OnDelete(action = OnDeleteAction.CASCADE)` | 親（Board）が削除された場合、この子（Card）も連動して削除されるという`ON DELETE CASCADE`制約をDB側に生成する（Hibernate拡張のアノテーション） |

`Label`エンティティも同様に、`board`フィールドへ`@ManyToOne` + `@JoinColumn` + `@OnDelete(CASCADE)`を持ちます。ボードが削除されたときにボード配下のカード・ラベルも自動的に削除される、という設計意図がこの3点セットのアノテーションに表れています。

> **Laravelとの対比**
> Eloquentの`belongsTo()`に近い関係です。ただしLaravelはリレーションを**メソッド**として定義する（例：`public function board() { return $this->belongsTo(Board::class); }`）のに対し、JPAは**フィールド＋アノテーション**として宣言します。またLaravelでのカスケード削除はマイグレーションファイルで`onDelete('cascade')`を指定するのに対し、JPAではエンティティ側に`@OnDelete`として書く点も違いです。

---

## 13. 複合主キー

`card`と`label`は多対多の関係にあり、その間を取り持つ中間テーブルが`card_label`です。中間テーブルの主キーは、`card_id`と`label_id`の**組み合わせ**（複合主キー）になります。

> **複合主キーとは？**
> 1つのカラムだけでは行を一意に特定できない場合に、複数カラムの組み合わせで一意性を担保する主キーです。中間テーブルの定番の設計です。

複合主キーそのものを表す専用クラスが`CardLabelId`です。

```java
@Embeddable
public class CardLabelId implements Serializable {

	@Column(name = "card_id")
	private Integer cardId;

	@Column(name = "label_id")
	private Integer labelId;

	// コンストラクタは省略

	@Override
	public boolean equals(Object o) {
		if (this == o) {
			return true;
		}
		if (!(o instanceof CardLabelId that)) {
			return false;
		}
		return Objects.equals(cardId, that.cardId) && Objects.equals(labelId, that.labelId);
	}

	@Override
	public int hashCode() {
		return Objects.hash(cardId, labelId);
	}
}
```

| 要素 | 意味 |
| --- | --- |
| `@Embeddable` | このクラスが「他のエンティティに埋め込まれる値の集まり」であることを示す。単独ではテーブルに対応しない |
| `implements Serializable` | 複合主キークラスはJPAの仕様上、直列化可能（`Serializable`）であることが要求される |
| `equals()` / `hashCode()`のオーバーライド | 複合主キーは「2つのフィールドの値が両方一致していれば同じ主キーとみなす」という**値としての同一性**判断が必要なため、JPAの仕様上、複合主キークラスでは`equals()`/`hashCode()`の実装が必須とされている |
| `o instanceof CardLabelId that` | Java 16以降の構文（パターンマッチング）。型チェックと同時にキャスト後の変数`that`を取得できる書き方 |

このIDクラスを実際に使うのが`CardLabel`エンティティです。

```java
@Entity
@Table(name = "card_label")
public class CardLabel {

	@EmbeddedId
	private CardLabelId id;

	@MapsId("cardId")
	@ManyToOne(optional = false, fetch = FetchType.LAZY)
	@JoinColumn(name = "card_id")
	@OnDelete(action = OnDeleteAction.CASCADE)
	private Card card;

	@MapsId("labelId")
	@ManyToOne(optional = false, fetch = FetchType.LAZY)
	@JoinColumn(name = "label_id")
	@OnDelete(action = OnDeleteAction.CASCADE)
	private Label label;
}
```

| アノテーション | 意味 |
| --- | --- |
| `@EmbeddedId` | このフィールド（`id`）が、`@Embeddable`クラスで表現された複合主キーであることを示す |
| `@MapsId("cardId")` | `card`フィールド（`@ManyToOne`で表現された関連）と、複合主キー内の`cardId`フィールドが同じ値を指すことを対応づける。これにより、外部キーの値と主キーの値を二重に管理せずに済む |

---

## 14. DBレベルの制約（@Check）

`Card`エンティティのクラス宣言には、次のアノテーションが付いています。

```java
@Check(constraints = "status in ('todo', 'doing', 'done')")
public class Card {
```

これは`status`カラムの値が`todo` / `doing` / `done`のいずれかであることを、**データベース自体のCHECK制約として**強制するものです。アプリケーション側（Service層でのバリデーション等）でも同様のチェックを行うことになりますが、それとは別にDBレベルでも制約をかけておくことで、仮にアプリケーションのバリデーションを経由しない経路（バグや将来の別クライアント）からデータが投入された場合でも、不正な値がDBに入ることを防げます。この「入口を複数用意して守る」考え方は、[3層の多重防御](./09-write-api-validation.md#3層の多重防御)と同じ発想です。

> 📄 カード・ボードの新規作成で、この多重防御の残り2層（フロントエンドの`maxLength`・Bean Validationの`@Size`）が実装されました。3層がそろった全体像は[29章](./09-write-api-validation.md#29-リクエストdtoとbean-validation)の「3層の多重防御」を参照してください。`@ColumnDefault`（[11章](#11-エンティティの基本アノテーション)）が実は「DDL生成にしか効かず、INSERT自体は守ってくれない」という別種の落とし穴は[31章](./09-write-api-validation.md#31-登録処理の中身)で扱います。

---

## 15. データモデルとの対応

ここまでのエンティティは、要件定義書のデータモデル（[7章](../requirements/04-data-model.md#7-データモデル)）のER図にそのまま対応しています。

| ER図上のテーブル | エンティティクラス |
| --- | --- |
| `BOARD` | `Board` |
| `CARD` | `Card` |
| `LABEL` | `Label` |
| `CARD_LABEL` | `CardLabel`（＋主キー部分の`CardLabelId`） |

エンティティの各フィールドの型・制約の根拠（なぜNOT NULLか、なぜこの型か等）は、要件定義書の[7.2 テーブル定義](../requirements/04-data-model.md#72-テーブル定義)・[7.3 設計上の補足](../requirements/04-data-model.md#73-設計上の補足)を参照してください。「何のためにこの制約があるか」という仕様上の理由は要件定義書側に、「Javaのコード上でどう表現するか」という実装の作法は本ドキュメントに、という役割分担です。

---

*Repository層の実装にあわせて、Spring Data JPAのリポジトリインターフェース・クエリメソッドについては[05-repository.md](./05-repository.md)（17〜19章）で解説しています。*
