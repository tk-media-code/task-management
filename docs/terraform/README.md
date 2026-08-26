# Terraform 学習ドキュメント

> このドキュメントは、本プロジェクト（タスク管理アプリ）のインフラを**コードとして記述・構築する**ために必要な、Terraformというツールの学習ノートです。
> AWSというクラウドサービス側の知識（アカウント設定・課金・各サービスの役割）は [docs/aws/](../aws/README.md) で扱っており、こちらは「Terraformというツールをどう使うか」を対象にします。
> あくまで**本プロジェクトのインフラ構築に必要な範囲**に絞っており、Terraformの全機能を網羅するものではありません。
> AWS・Terraformともに実戦経験がない状態を出発点として書いています。

### 本書の構成

[docs/spring-boot/](../spring-boot/README.md)・[docs/java/](../java/README.md)と同じく、全体像をつかむための**ハブ（このファイル）**と、章ごとの詳細をまとめた**詳細ファイル**（このディレクトリ内）に分かれています。

- このファイルには、各章の**見出しと概要**のみを載せています。まずはここを上から読めば全体像がつかめます。
- 詳しい解説（コマンド・設定例・落とし穴）が必要なときは、各章末尾の「📄 詳細」リンクから詳細ファイルを開いてください。
- 章番号は他の学習ドキュメントとは別に、このドキュメント内で1から振り直しています。

**ファイル構成**

| 章 | 内容 | 詳細ファイル |
| --- | --- | --- |
| 1〜4章 | Terraformとは何か（IaC・宣言的・プロバイダ・他ツールとの違い） | [01-overview.md](./01-overview.md) |
| 5〜8章 | インストールと基本ワークフロー | [02-install-and-workflow.md](./02-install-and-workflow.md) |
| 9〜12章 | state という中核概念 | [03-state.md](./03-state.md) |
| 13〜16章 | このプロジェクトでの決めごと | [04-project-conventions.md](./04-project-conventions.md) |
| 17〜22章 | 実際に書いてみて分かったこと | [05-writing-the-stack.md](./05-writing-the-stack.md) |

> **`infra/` に実際の `.tf` を作成しました。** 1〜16章は「Terraformとは何か・どう使うか」という準備を、17〜22章は「実際に書いてみて分かったこと」を扱います。実装は [infra/](../../infra/README.md) にあります。

## 目次

1. [IaC（Infrastructure as Code）とは何か](./01-overview.md#1-iacinfrastructure-as-codeとは何か)
2. [宣言的であるということ](./01-overview.md#2-宣言的であるということ)
3. [プロバイダの仕組み](./01-overview.md#3-プロバイダの仕組み)
4. [Terraformと似たツールの違い](./01-overview.md#4-terraformと似たツールの違い)
5. [WSL2へのインストール](./02-install-and-workflow.md#5-wsl2へのインストール)
6. [基本の4コマンド](./02-install-and-workflow.md#6-基本の4コマンド)
7. [AWS認証情報の渡し方](./02-install-and-workflow.md#7-aws認証情報の渡し方)
8. [バージョンの固定](./02-install-and-workflow.md#8-バージョンの固定)
9. [stateとは何か、なぜ必要か](./03-state.md#9-stateとは何かなぜ必要か)
10. [ローカルstateの限界](./03-state.md#10-ローカルstateの限界)
11. [S3バックエンドと状態ロック](./03-state.md#11-s3バックエンドと状態ロック)
12. [stateに機密が平文で入るということ](./03-state.md#12-stateに機密が平文で入るということ)
13. [ディレクトリ構成の方針](./04-project-conventions.md#13-ディレクトリ構成の方針)
14. [.gitignoreに入れるもの](./04-project-conventions.md#14-gitignoreに入れるもの)
15. [変数の渡し方と機密情報](./04-project-conventions.md#15-変数の渡し方と機密情報)
16. [AIにTerraformを書かせるときの安全策](./04-project-conventions.md#16-aiにterraformを書かせるときの安全策)
17. [data ソース](./05-writing-the-stack.md#17-data-ソース)
18. [リソース間の参照と依存関係](./05-writing-the-stack.md#18-リソース間の参照と依存関係)
19. [段階的なapplyの実践](./05-writing-the-stack.md#19-段階的なapplyの実践)
20. [file と templatefile、そして user_data](./05-writing-the-stack.md#20-file-と-templatefileそして-user_data)
21. [機密情報の扱い（実践編）](./05-writing-the-stack.md#21-機密情報の扱い実践編)
22. [default_tags と後片付け](./05-writing-the-stack.md#22-default_tags-と後片付け)

---

## 1. IaC（Infrastructure as Code）とは何か

インフラの構成をテキストとして記述し、バージョン管理する考え方です。手作業（コンソールでのクリック操作）と対比しながら、再現性・レビュー可能性・消し忘れの防止・AIに任せられること、という4つの利点を整理します。

📄 詳細：[01-overview.md](./01-overview.md#1-iacinfrastructure-as-codeとは何か)

---

## 2. 宣言的であるということ

Terraformの設定ファイルは「手順」ではなく「あってほしい状態」の記述です。そのため同じファイルを何度適用しても結果が同じ（冪等性）になります。Terraformが「コード」「state」「AWSの現状」の3つを突き合わせて差分だけを実行する仕組みと、`plan` で事前に差分を読める意味を解説します。

📄 詳細：[01-overview.md](./01-overview.md#2-宣言的であるということ)

---

## 3. プロバイダの仕組み

**Terraform本体にはAWSの知識が一切入っていません。** 実際にAWSのAPIを呼ぶのは `hashicorp/aws` というプラグイン（プロバイダ）です。この分離のおかげで同じ書き方で多数のサービスを扱えること、プロバイダが `terraform init` で取得され `.terraform/` に置かれることを解説します。

📄 詳細：[01-overview.md](./01-overview.md#3-プロバイダの仕組み)

---

## 4. Terraformと似たツールの違い

CloudFormation・AWS CDK・OpenTofuとの比較。学習情報の量とマルチクラウド対応を理由にTerraformを選ぶこと、および2023年のライセンス変更（BUSL）がこのプロジェクトの用途では影響しないことを整理します。

📄 詳細：[01-overview.md](./01-overview.md#4-terraformと似たツールの違い)

---

## 5. WSL2へのインストール

HashiCorp公式のaptリポジトリを登録してインストールする手順（GPG鍵の登録から）。Ubuntuの標準リポジトリにTerraformが無いこと、**`sudo` を伴うためAIエージェントには任せられない**こと、リソースを作らずにAWSとの疎通を確認する方法、複数バージョンを使い分けたくなった場合の選択肢を扱います。

📄 詳細：[02-install-and-workflow.md](./02-install-and-workflow.md#5-wsl2へのインストール)

---

## 6. 基本の4コマンド

`init` / `plan` / `apply` / `destroy` がそれぞれ何をするか。特に `plan` の出力に出る記号（`+` 作成・`~` 更新・`-` 削除・`-/+` **作り直し**）の読み方と、`Plan: X to add, Y to change, Z to destroy.` の `Z` を毎回確認すべき理由を扱います。

📄 詳細：[02-install-and-workflow.md](./02-install-and-workflow.md#6-基本の4コマンド)

---

## 7. AWS認証情報の渡し方

`.tf` ファイルにアクセスキーを書いてはいけない理由（コミットすると履歴に永久に残る）と、AWS CLIと同じ仕組みで認証情報が読まれること。リージョンはコードに固定し、秘密は環境から渡す、という切り分けを解説します。

📄 詳細：[02-install-and-workflow.md](./02-install-and-workflow.md#7-aws認証情報の渡し方)

---

## 8. バージョンの固定

`required_version` / `required_providers` による制約の書き方と、`~>`（悲観的バージョン制約）の意味。`.terraform.lock.hcl` を**コミットする**理由（`package-lock.json` と同じ役割）、そして**Terraform本体はダウングレードできない**ため `apt upgrade` で勝手に上がらないよう固定する運用を扱います。

📄 詳細：[02-install-and-workflow.md](./02-install-and-workflow.md#8-バージョンの固定)

---

## 9. stateとは何か、なぜ必要か

Terraformが持つ「自分がどのリソースを作ったか」の台帳です。stateが無いと「自分が作ったもの」と「もともとあったもの」を区別できず、`destroy` が管理外のリソースまで消しかねません。stateはTerraformの責任範囲を定める境界線そのものです。

📄 詳細：[03-state.md](./03-state.md#9-stateとは何かなぜ必要か)

---

## 10. ローカルstateの限界

既定のローカルstateが抱える3つの問題（失うと復旧が極めて面倒・共有できない・同時実行を防げない）を解説します。**PCが壊れただけで復旧困難になる**という点が、リモートバックエンドを使う動機になります。

📄 詳細：[03-state.md](./03-state.md#10-ローカルstateの限界)

---

## 11. S3バックエンドと状態ロック

stateをS3に置く設定と、`use_lockfile = true` による排他制御。**以前必要だったDynamoDBのテーブルはもう不要**（Terraform 1.11で正式版）である点は、古い記事を踏まないよう特に注意が要ります。「state置き場のバケットは誰が作るのか」という鶏と卵の問題の解き方も扱います。

📄 詳細：[03-state.md](./03-state.md#11-s3バックエンドと状態ロック)

---

## 12. stateに機密が平文で入るということ

stateはリソースの属性をそのまま記録するため、**DBのパスワードのような機密が平文のJSONとして書かれます**。`sensitive = true` は画面表示を伏せるだけで暗号化ではありません。`.env` と同格に扱う理由と、そもそもstateに機密を入れない3つの方法（AWS側に生成させる・write-only引数・実行時に外から注入）を解説します。

📄 詳細：[03-state.md](./03-state.md#12-stateに機密が平文で入るということ)

---

## 13. ディレクトリ構成の方針

Terraformのコードをリポジトリ内の `infra/` に置く理由（アプリとインフラの変更が同時に必要になる場面が多い）と、最初から凝った構成にしないという方針を扱います。

📄 詳細：[04-project-conventions.md](./04-project-conventions.md#13-ディレクトリ構成の方針)

---

## 14. .gitignoreに入れるもの

`.terraform/`・`*.tfstate`・`*.tfvars` を除外する理由と、**`.terraform.lock.hcl` は逆にコミットする**という区別。まだ `infra/` が無い段階で先に `.gitignore` を入れておく理由（作ってから設定する順序だと、その間に事故が起きる）も説明します。

📄 詳細：[04-project-conventions.md](./04-project-conventions.md#14-gitignoreに入れるもの)

---

## 15. 変数の渡し方と機密情報

`variable` の宣言と、値を渡す4つの方法（`default`・`terraform.tfvars`・`TF_VAR_` 環境変数・対話入力）の使い分け。`sensitive = true` の効果と、それが暗号化ではないという限界を扱います。

📄 詳細：[04-project-conventions.md](./04-project-conventions.md#15-変数の渡し方と機密情報)

---

## 16. AIにTerraformを書かせるときの安全策

インフラのコードは間違えると課金とデータ損失に直結します。**`plan` の出力を人間が読むことが唯一かつ最大の安全弁**であること、`-auto-approve` を使わないこと、`prevent_destroy` で守ること、段階的に `apply` すること、そしてコンソールでの手作業を混ぜないことを扱います。

📄 詳細：[04-project-conventions.md](./04-project-conventions.md#16-aiにterraformを書かせるときの安全策)

---

## 17. data ソース

「作る」のではなく「既にあるものを調べる」ブロックです。AMI IDをコードに直接書かない理由と、**`most_recent = true` が招く「applyのたびにインスタンスが作り直される」問題**、そしてそれを止める `lifecycle { ignore_changes }` を扱います。

📄 詳細：[05-writing-the-stack.md](./05-writing-the-stack.md#17-data-ソース)

---

## 18. リソース間の参照と依存関係

`aws_vpc.main.id` と書くだけで実行順序が決まる仕組み（暗黙の依存関係）と、依存関係のないリソースが並列に作られること、`depends_on` を多用しないほうがよい理由を扱います。

📄 詳細：[05-writing-the-stack.md](./05-writing-the-stack.md#18-リソース間の参照と依存関係)

---

## 19. 段階的なapplyの実践

`.tf` ファイルを1つずつ足していけば、それがそのまま段階的なapplyになります。**`-target` を使わない理由**と、`plan` 出力の読み方（`+`・`~`・`-`・`-/+` の意味）、そして**ネットワークとセキュリティグループの段階は課金がゼロ**なので `plan` を読む練習に適していることを扱います。実際の構築記録も載せています。

📄 詳細：[05-writing-the-stack.md](./05-writing-the-stack.md#19-段階的なapplyの実践)

---

## 20. file と templatefile、そして user_data

**`file("~/...")` が展開されずエラーになる**こと（`pathexpand()` が必要）と、**user_dataは変更しても反映されない**という最も分かりにくい挙動、そしてそれを可視化する `user_data_replace_on_change` を扱います。設定ファイルをTerraformに持たせるか別経路で配るかの判断基準（変更の頻度）も整理しています。

📄 詳細：[05-writing-the-stack.md](./05-writing-the-stack.md#20-file-と-templatefileそして-user_data)

---

## 21. 機密情報の扱い（実践編）

[12章](./03-state.md#12-stateに機密が平文で入るということ)で扱った「stateに平文で入る」を実際に確認し、`sensitive` なoutputを `terraform output -raw` でスクリプトから読む使い方とその是非、**`tls_private_key` を使ってはいけない理由**、そして `validation` で危険な値を機械的に弾く方法を扱います。

📄 詳細：[05-writing-the-stack.md](./05-writing-the-stack.md#21-機密情報の扱い実践編)

---

## 22. default_tags と後片付け

プロバイダの `default_tags` で全リソースにタグが付く仕組みと、**それがdestroy後の「消し忘れ探し」に効く**こと、destroyの手順と確認すべき対象、そして**「一緒に消えてよいか」でstateを分ける**という判断基準を扱います。

📄 詳細：[05-writing-the-stack.md](./05-writing-the-stack.md#22-default_tags-と後片付け)

---

## このドキュメントの更新ルール

- インフラ構築を進める中で新しいTerraformの概念・機能（モジュール、`for_each`、`data` ソース、`import`、ワークスペースなど）が登場したら、**都度このドキュメント群を更新すること**を本プロジェクトのルールとします。
- 既存ファイルへの追記で収まる内容はそのファイルに追記し、独立したまとまりを持つ新しいトピックは `05-xxx.md` のように連番でファイルを追加してください。章番号もこのREADMEの続き（17章、18章…）として振ってください。
- 新しいファイルを追加した場合は、このREADMEの「ファイル構成」表と「目次」の両方を更新し、ハブと詳細ファイルの対応が常に成立している状態を保ってください。
- **AWSのサービスそのものの説明（そのサービスが何をするものか、いくらかかるか）は [docs/aws/](../aws/README.md) 側の更新ルールに従い、そちらに追記してください。** 両方にまたがる話題（例：S3バックエンド）は、Terraformの機能としての説明をこちら、AWSサービスとしての説明をあちらに置き、相互リンクしてください。
- バージョン番号など**陳腐化しやすい情報には、いつ時点の値かを明記**してください。特にTerraformは仕様変更が速く、古い手順（DynamoDBによるstateロックなど）がネット上に大量に残っています。

---

*本ドキュメントは開発と並行して育てていく学習ノートです。Terraformで分からないことが出てきたら、まずここに解説がないか確認し、無ければ追記してください。*
