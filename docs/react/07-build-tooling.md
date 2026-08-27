# npm・Viteとビルド周りの設定

[← React学習ドキュメントトップへ戻る](./README.md)

> 元の学習ドキュメントにおける **16〜17章** をまとめています。

---

## 16. npm・Vite・tsconfigと環境変数

> **npmとVite、それぞれの役割とは？**
> **npm**は依存パッケージのインストールとスクリプトの実行を担うツール、**Vite**はTypeScript（JSX含む）をブラウザ用のJavaScriptへ変換し、開発サーバー・本番ビルドを提供するツールです。[docs/spring-boot 6章](../spring-boot/02-build-config.md#6-gradleとは)のGradleに近い立ち位置ですが、npmとViteで役割が分かれている点がGradle（1つのツールで依存解決からビルドまで担う）と異なります。

### `package.json`：依存パッケージとスクリプト

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "oxlint",
    "preview": "vite preview"
  },
  "dependencies": {
    "@tailwindcss/vite": "^4.3.3",
    "react": "^19.2.7",
    "react-dom": "^19.2.7",
    "react-router": "^8.3.0",
    "tailwindcss": "^4.3.3"
  },
  "devDependencies": {
    "@types/node": "^24.13.2",
    "@types/react": "^19.2.17",
    "@types/react-dom": "^19.2.3",
    "@vitejs/plugin-react": "^6.0.3",
    "oxlint": "^1.71.0",
    "typescript": "~6.0.2",
    "vite": "^8.1.1"
  }
}
```

- `dependencies`：**実行時にも必要な**パッケージです。`react`・`react-dom`（Reactの本体）、`react-router`（[docs/react 13章](./05-router.md#13-react-routerの基本)）、`tailwindcss`（[17章](#17-tailwind-cssの読み方)）が並びます。
- `devDependencies`：**開発時（ビルド時）にだけ必要な**パッケージです。`typescript`（コンパイラ自体）、`vite`・`@vitejs/plugin-react`（開発サーバー・ビルドツール）、`oxlint`（リンター、[docs/react 9章](./03-state-effect.md#9-フックのルール)）、`@types/react`のような**型定義だけを提供するパッケージ**（`react`本体はJavaScriptで書かれているため、TypeScriptから見た型情報を別パッケージとして補っています）が並びます。
- `scripts`：`npm run dev`のように、`npm run <名前>`で実行できるコマンドの別名です。`build`が`tsc -b && vite build`という2段階になっている理由は[docs/typescript 1章](../typescript/01-basics.md#1-typescriptとは)で扱いました。

> **PHP・Laravelとの対比**
> `package.json`の`dependencies`/`devDependencies`は、LaravelでいうComposerの`composer.json`にとても近い役割です。`^19.2.7`のような`^`付きのバージョン指定（メジャーバージョンを固定したまま、それ以降の新しいバージョンを許容する）も、Composerのバージョン制約と似た考え方です。

### `vite.config.ts`：Viteの設定ファイル

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: true,
    port: 5173,
  },
})
```

`plugins: [react(), tailwindcss()]`は、ViteにReact（JSXの変換など）とTailwind CSS（[17章](#17-tailwind-cssの読み方)）のサポートを追加するプラグインです。`server.host: true`のコメントに、Docker環境ならではの設定理由があります。

```typescript
// 既定値の localhost（127.0.0.1）だとコンテナ内部からしか listen を受け付けられない。
// 0.0.0.0 で待ち受けることで、docker-compose.yml の ports 設定によるホストからの
// ポートフォワード（http://localhost:5173）がコンテナに届くようにする。
```

`host: true`は、開発サーバーの待ち受けアドレスを`127.0.0.1`（同じコンテナの中からしかアクセスできない）ではなく`0.0.0.0`（どのネットワークインターフェースからのアクセスも受け付ける）に変える設定です。Dockerコンテナの中でViteを動かし、それをホストOS側のブラウザから見る、という本プロジェクトの開発環境で必須の設定になっています。

### `tsconfig.*.json`：3つのファイルに分かれている理由

```json
// tsconfig.json（ルート）
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

`tsconfig.json`自体は設定を持たず、`references`で2つの子設定を束ねているだけです。分かれている理由は、**ブラウザで動くコード**（`src/`配下、`tsconfig.app.json`が担当）と、**Node.js上でVite自体の設定を書くコード**（`vite.config.ts`、`tsconfig.node.json`が担当）とで、実行環境が異なり、使える構文やライブラリの型（`lib`設定）も違うためです。`tsconfig.app.json`は`"lib": ["ES2023", "DOM"]`（ブラウザのDOM API、[docs/typescript 14章](../typescript/06-async.md#14-fetchとabortcontroller)の`fetch`など）を含みますが、`tsconfig.node.json`は`"lib": ["ES2023"]`のみで`"types": ["node"]`（Node.js固有の型）を使います。1つの`tsconfig.json`で全部を賄おうとすると、「ブラウザには無いはずのNode.js APIが、`src/`のコードからも見えてしまう」といった環境の混同が起こり得るため、目的別に分割されています。

### 環境変数：`import.meta.env`と`.env.development`

`api/client.ts`は、バックエンドのURLをコードに直接書かず、環境変数から読み取っています。

```typescript
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? ''
```

値は`frontend/.env.development`から供給されます。

```bash
# バックエンドAPIのベースURL。
# ブラウザはコンテナの中ではなくホストOS上で動くため、Composeのサービス名
# （http://backend:8080）ではなく、ホストに公開されたポートを指す必要がある
VITE_API_BASE_URL=http://localhost:8080
```

`import.meta.env`はViteが提供する環境変数の入れ物で、`VITE_`という接頭辞が付いた変数だけが、ビルド時にクライアント側のJavaScriptへ文字列として埋め込まれます（`VITE_`が付かない変数は、意図的にブラウザへ渡されません。ブラウザから丸見えになるため秘密情報を書いてはいけない、という`.env.development`のコメントとも対応します）。`vite-env.d.ts`は、この`import.meta.env`が持つプロパティに`VITE_API_BASE_URL`という型を与えるファイルです（[docs/typescript 4章](../typescript/02-object-types.md#4-interfaceと宣言のマージ)の`interface`宣言のマージを参照）。

`?? ''`（[docs/typescript 6章](../typescript/02-object-types.md#6-nullundefinedとstrictnullchecks)）が必要な理由もコメントに明記されています。`npm run build`は`.env.development`を読み込まない**productionモード**で動くため、この変数は`undefined`になります。空文字にフォールバックすることで、リクエスト先が相対URL（`/api/boards`のような、ベースURLを持たないパス）になり、画面とAPIを同一オリジンに配置する本番構成でもそのまま動くようになっています。

---

## 17. Tailwind CSSの読み方

> **Tailwind CSSとは？**
> `rounded-lg`・`bg-white`・`p-3`のような、あらかじめ定義された小さなクラスを`className`に並べていくことで見た目を組み立てる、**ユーティリティファースト**というアプローチのCSSフレームワークです。独自のCSSファイルにクラスを1つずつ定義していく従来のスタイルとは対照的です。

`src/index.css`の中身は、コメントを除けば実質1行だけです。

```css
/*
 * Tailwind CSS v4 の読み込み方式。v3までの tailwind.config.js / postcss.config.js による
 * ビルド設定は不要で、この1行だけで base/components/utilities 相当のスタイルが有効になる
 * （実際のコンパイルは vite.config.ts に追加した @tailwindcss/vite プラグインが行う）。
 */
@import "tailwindcss";
```

コメントにあるとおり、Tailwind CSS v4はv3までとは読み込み方式が変わり、`tailwind.config.js`のような別ファイルでのビルド設定が不要になりました。`@import "tailwindcss";`の1行だけで、ユーティリティクラス一式が有効になります。実際にソースコードを走査してCSSを生成する処理は、`vite.config.ts`の`tailwindcss()`プラグイン（[16章](#16-npmvitetsconfigと環境変数)）が担っています。ソースコード全体（`.tsx`ファイルの`className`に書かれた文字列）を走査し、実際に使われているユーティリティクラスだけを含む最終的なCSSを生成します。`components/StatusColumn.tsx`のようなコードで使われている、次のようなクラスがその一例です。

```typescript
className="flex flex-col gap-3 rounded-lg border border-slate-300 bg-slate-50 p-3"
```

`flex`（display: flex）・`flex-col`（縦方向に並べる）・`gap-3`（要素間の余白）・`rounded-lg`（角丸）・`border`＋`border-slate-300`（枠線とその色）・`bg-slate-50`（背景色）・`p-3`（内側の余白）と、1つ1つのクラスが1つのCSSプロパティに対応しています。独自の名前を持つCSSクラス（例えば`.card`）を新たに定義するのではなく、既存のユーティリティを組み合わせて見た目を作る、というのがTailwindの基本的な流儀です。

### なぜクラス名を動的に組み立ててはいけないのか

`components/StatusMessage.tsx`のコメントに、Tailwindを使ううえで重要な制約が説明されています。

```typescript
/**
 * 種類ごとのTailwindクラス。
 * Tailwindはビルド時にソースコードを文字列として走査してCSSを生成するため、
 * `bg-${color}-50` のように文字列を組み立てて指定するとクラスを見つけられず、
 * スタイルが当たらない。必ず完全なクラス名をソース中にそのまま書くこと。
 */
const KIND_CLASSES: Record<StatusKind, string> = {
  loading: 'border-slate-200 bg-white text-slate-500',
  error: 'border-red-200 bg-red-50 text-red-700',
  empty: 'border-slate-200 bg-white text-slate-400',
}
```

Tailwindがどのクラスを実際のCSSとして出力するかは、**ソースコードの文字列をそのまま検索して**決まります（実行時にJavaScriptとして評価して決まるわけではありません）。`` `bg-${color}-50` ``のようにテンプレートリテラルで組み立てると、ソースコード上には`bg-`という断片しか存在せず、Tailwindはそれが実際に何色になり得るかを知る術がないため、対応するCSSを生成できません（実行時にその文字列が仮に`bg-red-50`になったとしても、CSS自体がビルドされていなければスタイルは当たりません）。この制約を回避するため、`StatusMessage`は`Record<StatusKind, string>`（[docs/typescript 8章](../typescript/03-generics.md#8-recordとreadonlyとas-const)）というオブジェクトに、**完全な形のクラス名の文字列**をキーごとに書き並べています。こうすればソースコード上に`'border-red-200 bg-red-50 text-red-700'`という文字列がそのまま存在するため、Tailwindはこれを確実に検出できます。

### Tailwindで表現できない値は`style`属性へ

[docs/react 3章](./02-component-jsx.md#3-コンポーネントとjsx)で見たとおり、`components/LabelChip.tsx`はラベルの色を`className`ではなく`style`属性で指定していました。

```typescript
style={{ backgroundColor: label.color, color: getContrastTextColor(label.color) }}
```

これも今回の制約と同じ理由です。ラベルの色はデータベースに保存された任意の16進カラーコード（`#e74c3c`など）であり、Tailwindの決まったクラス名の集合には存在しません。ビルド時に静的に決まらない「実行時にしか分からない値」は、Tailwindのユーティリティクラスではなく、素のCSSと同じ`style`属性で直接指定する、という使い分けになります。

### レスポンシブ修飾子（`md:`など）

`components/CardItem.tsx`の「移動 ▾」`<select>`は、次のように`md:hidden`というクラスを持っています。

```typescript
className="mt-2 w-full rounded border border-slate-200 bg-slate-50 px-2 py-1 text-xs text-slate-500 disabled:opacity-50 md:hidden"
```

Tailwindは`md:`のような**ブレークポイント修飾子**をクラス名の前に付けることで、「画面幅がある条件を満たすときだけ」そのユーティリティを適用できます。既定のブレークポイントはいくつか用意されていますが、本プロジェクトで使っているのは`md`（`min-width: 768px`）だけです。`md:hidden`は「768px以上の画面幅では`display: none`にする」という意味で、逆に言えば768px未満（スマートフォン幅）でだけ表示される、ということになります。

修飾子の付いていない素の`hidden`のようなクラスは常時（全ての画面幅で）適用されるため、`md:hidden`のように修飾子付きのクラスと組み合わせて初めて「ある画面幅**未満**でだけ表示する」という指定になります。逆に「768px以上でだけ表示する」なら、既定で`hidden`を指定したうえで`md:block`（や`md:flex`など、要素本来の`display`値）を付け足す、という書き方をします。`components/BoardDetailView.tsx`・`CrossBoardView.tsx`の`grid gap-4 md:grid-cols-3`（3列カンバンを768px未満では1列に、768px以上では3列にする）も同じ修飾子の仕組みで、こちらは既存のCSS（メディアクエリ）で言う`@media (min-width: 768px) { ... }`にちょうど対応します。

---

## 33. oxlintの設定強化

実装が一通り完了した段階の品質チェックで、[9章](./03-state-effect.md#9-フックのルール)で触れた`.oxlintrc.json`を見直しました。導入直後は`react/rules-of-hooks`・`react/only-export-components`の2ルールしか明示的に有効にしておらず、oxlintが持つ検出力のごく一部しか使えていなかったためです。

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc", "jsx-a11y", "promise", "import"],
  "categories": {
    "suspicious": "warn"
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }],
    "react/react-in-jsx-scope": "off",
    "import/no-unassigned-import": "off"
  }
}
```

### `categories`：ルールをまとめて有効にする

oxlintのルールは`correctness`（既定で有効）・`suspicious`・`pedantic`・`perf`・`style`・`restriction`・`nursery`という7つのカテゴリに分類されています。個々のルールを1つずつ`rules`に書き並べる代わりに、`categories`でカテゴリ単位の重要度を指定できます。`"suspicious": "warn"`は「間違っている可能性が高いコード」のカテゴリを警告として有効にする設定です。

### `plugins`：フレームワーク固有の検査を追加する

素のJavaScript/TypeScriptだけでなく、Reactやアクセシビリティ（a11y）、Promiseの使い方など、特定のライブラリ・パターンに特化した検査を追加するのが`plugins`です。今回`jsx-a11y`（アクセシビリティ）・`promise`（Promiseの使い方）・`import`（import文の妥当性）の3つを追加しました。

### 誤検知への対処：まず動かして確かめる

`suspicious`カテゴリと3プラグインを機械的に足しただけでは、実装に合わない誤検知も一緒に増えてしまいます。実際に試したところ、次の2つが誤検知でした。

| ルール | 誤検知の内容 |
| --- | --- |
| `react/react-in-jsx-scope` | 「JSXを使うファイルは`React`をimportしていなければならない」という、React 16以前のJSX変換方式を前提にしたルール。本プロジェクトは`tsconfig.app.json`の`"jsx": "react-jsx"`（React 17以降の新しいJSX変換）を使っており、`React`のimportが無くてもJSXは動く。有効にすると全てのJSXを含む行（実測236件）が誤って指摘される |
| `import/no-unassigned-import` | 「importした結果を変数に代入していないimportは怪しい」というルール。`main.tsx`の`import './index.css'`はCSSを読み込むためだけのVite標準の書き方で、代入する対象が無いのが正しい |

いずれも`.oxlintrc.json`の`rules`で個別に`"off"`にすることで、他の指摘に埋もれさせずに除外しています。`react-perf`プラグイン（`jsx-no-new-function-as-prop`等）は試した結果、コールバックpropsすべてに反応してノイズが大きく、このプロジェクトの規模には見合わないと判断し、そもそも導入していません。「カテゴリ・プラグインを追加したら、まず実行して結果を見る」という進め方が、oxlintに限らず静的解析ツール全般との付き合い方の基本です。

### 実際に検出された指摘

誤検知を除外した状態で残った指摘は次の8件でした（2026年8月時点。今後の対応は品質チェックの結果として別Issueで管理する方針としています）。

| ルール | 内容 |
| --- | --- |
| `promise/always-return`（2件） | `hooks/useApi.ts`・`hooks/useLabelsByBoard.ts`の`.then()`が値を返していない |
| `jsx-a11y/click-events-have-key-events`・`no-static-element-interactions`（各2件） | `components/CardDetailModal.tsx`・`BoardManageModal.tsx`の背景オーバーレイ`<div onClick>`に、キーボード操作の代替が無い |
| `jsx-a11y/prefer-tag-over-role`（2件） | 同じ2箇所の`role="dialog"`は、意味の近いHTML標準要素`<dialog>`に置き換えられる |

### `exhaustive-deps`——ルール名が違っただけだった

[9章](./03-state-effect.md#9-フックのルール)で扱った`react/rules-of-hooks`と対になるのが、`useEffect`の依存配列漏れを検出する**exhaustive-deps**です。当初は`"react/exhaustive-deps": "warn"`と書いて有効化を試み、読み込まれるルール総数が変化しないことから「oxlintでは有効化できない」と結論づけていました。

しかし後日（#67の対応時）に改めて調べたところ、**プラグイン名の指定が誤っていただけ**でした。正しくは`react`ではなく`react-hooks`です。

```json
"rules": {
  "react/rules-of-hooks": "error",
  "react-hooks/exhaustive-deps": "error"
}
```

紛らわしいのは、`rules-of-hooks`のほうが`react/`でも`react-hooks/`でも通ってしまう点です。そのため「`react/`接頭辞で書けばよい」という誤った一般化が起き、`react/exhaustive-deps`という存在しない名前を指定していました。

**なぜ間違いに気づけなかったのか**も、この件の教訓です。oxlintは**存在しないルール名に対しては設定ファイルの読み込み自体を失敗させます**。

```
Failed to parse oxlint configuration file.
  x Rule 'this-rule-does-not-exist' not found in plugin 'react'
```

このエラーが出なかった＝名前は正しかった、と判断できたはずでした。当時は「ルール総数が変わらない」という間接的な観察だけで結論を出してしまい、この直接的な手がかりを使っていませんでした。**「動かない」と結論づける前に、ツールがエラーを出す条件を一度確かめてみる**——という手順を踏んでいれば、より早く気づけた種類の誤りです。

### 意図的に省略した依存配列を「意図的だ」と示す

有効化したことで、`pages/SearchView.tsx`・`components/SortableBoardRow.tsx`が依存配列から意図的に外している値（それぞれ`keywordInUrl`・`board.name`）が、実際にルールの検出対象になりました。どちらも[14章](./05-router.md#14-urlを状態の置き場所にする)・[29章](./10-board-management.md#29-インライン改名編集とescapeの競合)で述べたとおり、**含めると壊れる**ため意図的に外しているものです。

そこで、これらの箇所には抑制コメントを添えています。

```typescript
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedKeyword, fromPath])
```

以前は`// eslint-disable-next-line ...`と書かれていました。oxlintはESLint互換のためこの接頭辞も解釈するので実際に機能はしていたのですが、このプロジェクトにESLintは導入されていません。「動いてはいるが、書いてあるツール名が実在しない」という状態は読み手を迷わせるため、`oxlint-`接頭辞へ揃えました。

抑制コメントは、無いほうが良いものと思われがちです。しかしこの2箇所については逆で、**「ルールが検出しうる状態で、明示的に抑制している」ことに意味があります**。コメントが無ければ「依存配列に入れ忘れた」のか「意図して外した」のかを、コードだけでは区別できません。ルールを有効化して初めて、この区別が機械的に強制されるようになりました。

### push前チェックとの関係

oxlintは既定で「`warn`扱いの指摘だけが残っている状態」を失敗として扱いません（終了コード0）。`--deny-warnings`オプションを付けると、この挙動を変えて`warn`扱いの指摘（`suspicious`カテゴリや上記8件を含む）も失敗として扱えます。

このoxlintの実行は、現在はCIではなく**push前のローカルチェック**（`scripts/quality-check.sh`。Claude Code / Cursor 利用時はガードフック（`.claude/hooks/guard.cjs` / `.cursor/hooks/guard.cjs`）が`git push`実行前に自動で呼び出す）が担っています。CIはPRを作成した「後」にしか走らず問題に気づくタイミングとして遅いため、静的解析はpush前チェック側に寄せ、CIは`tsc -b && vite build`が通ることの確認に絞っています（詳しい経緯は[CONTRIBUTING.md 5章](../../CONTRIBUTING.md#5-push前の品質チェック)参照）。

[CONTRIBUTING.md 5章](../../CONTRIBUTING.md#5-push前の品質チェック)の方針では、上記8件（`jsx-a11y`の6件はIssue #66、`promise`の2件はIssue #73で管理）が解消されるまでの間は`--deny-warnings`を付けず、まずerror（`correctness`カテゴリと、上で有効化した`react-hooks/exhaustive-deps`。現状0件）のみでゲートしています。指摘を1件ずつ解消し終えたら`scripts/quality-check.sh`内の`OXLINT_ARGS`に`--deny-warnings`を付け、以後の新しい警告もpush前チェックで検出できる状態へ引き上げる想定です。
