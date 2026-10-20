# このプロジェクトでの決めごと

[← Terraform学習ドキュメントトップへ戻る](./README.md)

> 本ドキュメントにおける **13〜16章** をまとめています。

---

## 13. ディレクトリ構成の方針

### 13.1 リポジトリ内の `infra/` に置く

Terraformのコードは、アプリのコードと同じリポジトリの **`infra/`** 配下に置く。

```
task-management/
├── backend/     Spring Boot
├── frontend/    React
├── db/
├── docs/
└── infra/       ← Terraform（構成が決まってから作る）
```

アプリと別リポジトリに分ける流儀もあるが、本プロジェクトは個人開発で、**アプリの変更とインフラの変更が同時に必要になる場面が多い**（環境変数を1つ増やす、ポートを変える、など）。同じリポジトリなら1つのPRで完結し、「アプリだけマージしてインフラを忘れる」が起きない。

### 13.2 実際の構成

構成が EC2 1台 + RDS に決まったことを受けて、`infra/` は次のようになっている。

```
infra/
├── providers.tf     プロバイダとバージョン制約、全リソース共通のタグ
├── variables.tf     入力変数の宣言
├── network.tf       VPC・サブネット・ルートテーブル・DBサブネットグループ
├── security.tf      セキュリティグループ・キーペア
├── compute.tf       AMIの検索とEC2
├── database.tf      RDS
├── outputs.tf       出力値
├── files/           EC2に配置するファイル
├── terraform.tfvars 変数の値（コミットしない。パスワードは書かない）
├── terraform.op     1Passwordの参照の雛形（実値は入っていないのでコミットする）
└── account/         予算アラート（stateを分けている）
```

**`main.tf` を複数のファイルに分けているが、これは「凝った構成」ではない。** Terraformは同じディレクトリの `.tf` をすべて読み込んで連結して扱うため、ファイル分割は人間が読みやすくするためのものでしかない。

分割する実利は、[16.5](#165-少しずつ適用する)の「少しずつ適用する」を **`-target` を使わずに実現できる**ことにある。ファイルを1つずつ足していけば、それがそのまま段階的なapplyになる（詳細は [19章](./05-writing-the-stack.md#19-段階的なapplyの実践)）。

### 13.3 account/ をライフサイクルで分けている理由

予算アラートだけは、本体とstateを分けて `infra/account/` に置いている。

**アプリを消しても残っていてほしい唯一のリソースだから**である。同じstateに置くと `terraform destroy` で一緒に消え、「消し忘れに気づくための仕組み」そのものが失われる。

これは環境ごとの分割（dev/prod）ではなく、**ライフサイクルによる分割**である。判断基準は「**一緒に消えてよいか**」で、下記の禁止事項には当たらない。

> 最初から「モジュール化」「環境ごとのディレクトリ分割」といった凝った構成にしないこと。1つの環境しか無い段階で分割すると、抽象化のコストだけがかかって利点が出ない。必要になってから分ける。

---

## 14. .gitignoreに入れるもの

### 14.1 除外するもの

リポジトリルートの `.gitignore` に以下を追加済みである。

| パターン | 理由 |
| --- | --- |
| `.terraform/` | `terraform init` が取得するプロバイダのバイナリ。数百MBになり、`init` すれば復元できる |
| `*.tfstate` / `*.tfstate.*` | **機密が平文で入る**（[12章](./03-state.md#12-stateに機密が平文で入るということ)）。`.tfstate.backup` も同様 |
| `*.tfvars` / `*.tfvars.json` | 変数の値。パスワードなどを書く可能性がある |
| `*.pem` / `*.key` / `id_rsa` / `id_ed25519` | SSHの秘密鍵。漏れると誰でもサーバーに入れる。秘密鍵は1Passwordに置き、`~/.ssh` には公開鍵だけを置く運用なので、リポジトリ内に現れること自体が事故のサイン |

### 14.2 `.terraform.lock.hcl` は**コミットする**

これは除外しない。プロバイダのバージョンとチェックサムを記録したロックファイルで、コミットしておくことで**どの端末でも同じバージョンのプロバイダが入る**（[8.2](./02-install-and-workflow.md#82-terraformlockhcl)）。

`.gitignore` に入れてしまうと、実行する端末ごとにプロバイダのバージョンが変わり、「自分の環境では動くのに」の原因になる。npmの `package-lock.json` をコミットするのと同じ理由である。

### 14.3 除外は「事故が起きる前に」入れる

`infra/` はまだ存在しないが、**`.gitignore` は先に入れてある**。これは「ファイルを作ってから除外設定をする」順序だと、その間に一度コミットしてしまう事故が起きるため。一度コミットされた機密は、履歴を書き換えない限り消えない。

---

## 15. 変数の渡し方と機密情報

### 15.1 変数の宣言

```hcl
# variables.tf
variable "db_password" {
  description = "RDSのマスターパスワード"
  type        = string
  sensitive   = true    # 実行ログや plan 出力で値を伏せる
}

variable "aws_region" {
  description = "リソースを作成するリージョン"
  type        = string
  default     = "ap-northeast-1"
}
```

### 15.2 値の渡し方と、その使い分け

| 方法 | 書き方 | 使いどころ |
| --- | --- | --- |
| `default` | `variables.tf` に直接 | 秘密でなく、変える理由も無い値（リージョンなど） |
| `terraform.tfvars` | `ssh_allowed_cidr = "..."` | 環境ごとに変わるが、秘密ではない値。**コミットしない** |
| 環境変数 | `TF_VAR_db_password=... terraform apply` | 秘密の値。ファイルに残したくない値（本プロジェクトではこちらでパスワードを渡す。[15.4](#154-パスワードを1passwordから渡す)） |
| 対話入力 | 値を渡さないとTerraformが尋ねてくる | 手元で1回だけ実行する場合 |

`TF_VAR_` プレフィックスを付けた環境変数は、対応する名前の変数に自動で入る（`TF_VAR_db_password` → `var.db_password`）。

### 15.3 `sensitive = true` の効果と限界

`sensitive = true` を付けると、`plan` や `apply` の出力でその値が `(sensitive value)` と表示される。**うっかり画面やログに出さないための機能**である。

ただし**stateには平文で書き込まれる**（[12.1](./03-state.md#121-これは仕様である)）。「sensitiveを付けたから安全」ではないことを、はっきり区別しておくこと。本当に守りたい値は [12.3](./03-state.md#123-そもそもstateに入れない) の方法でstateに入れないようにする。

### 15.4 パスワードを1Passwordから渡す

本プロジェクトでは、RDSのマスターパスワード（`db_password`）を `terraform.tfvars` に**書かない**。1Passwordの tk-media 保管庫にあるアイテム `task-management-aws` のフィールド `db-password` から、環境変数 `TF_VAR_db_password` として渡す。

**tfvars に書かない理由は、平文のファイルが手元に残ることにある。** tfvars は `.gitignore` 済みでコミットはされないが、ディスク上には平文で居座り、バックアップや同期、AIエージェントの読み取りの対象になりうる。

**ただし、環境変数で渡してもstateには平文で入る。** これは渡し方に関係しない（[15.3](#153-sensitive--true-の効果と限界)）。だから、せめて入口のファイル（tfvars）は平文にしない。そのうえで、`terraform.tfstate` と `terraform.tfstate.backup` は秘密として扱う（[12.2](./03-state.md#122-したがってstateは-env-と同格に扱う)）。

環境変数なら、パスワードはコマンドを実行している間のプロセスの中にだけ存在し、入力用のファイルとしては残らない。

**既存の `terraform.tfvars` に `db_password` の行があれば消す。** tfvars は環境変数より優先されるので、残っていると `TF_VAR_db_password` が黙って無視される。

**`TF_VAR_<変数名>` という名前の環境変数は、Terraformが同名の変数の値として自動で読む。** `variables.tf` も `.tf` のコードも変えずに、値の入口だけを差し替えられる。

**1Passwordの参照（`op://保管庫/アイテム/フィールド`）は、実行の瞬間に値へ置き換える。** 参照を並べた雛形が `infra/terraform.op` で、実値を含まないのでコミットしてよい。

```
TF_VAR_db_password=op://tk-media/task-management-aws/db-password
```

リポジトリのルートで実行する。`oprun` も `op run` も、雛形のパスを今いるディレクトリから読み、コマンドも同じディレクトリで動かすため、Terraformには `-chdir=infra` を付ける。

```bash
# WSL（oprun は op.exe inject を通すラッパーで、リポジトリには含まれない）
oprun infra/terraform.op -- terraform -chdir=infra plan -input=false
oprun --no-masking infra/terraform.op -- terraform -chdir=infra apply

# 他のOS（1Password CLI）
op run --env-file=infra/terraform.op -- terraform -chdir=infra plan -input=false
op run --no-masking --env-file=infra/terraform.op -- terraform -chdir=infra apply
```

`oprun` は `op run` と同じく出力をマスクし、先頭の `--no-masking` で外せる前提で書いている。`apply`（と `destroy`）に `--no-masking` を付けるのは、確認プロンプトに人が `yes` と答える対話であり、出力を加工する既定のマスキング（秘密の値の伏せ字化）を通すと、その対話を邪魔しうるため。値の決まり（英数字のみ16〜41文字）は `variables.tf` の `validation` が検査する（[21.4](./05-writing-the-stack.md#214-validationで機械的に防ぐ)）。

---

## 16. AIにTerraformを書かせるときの安全策

本プロジェクトは、インフラの構築とデプロイをAIに任せる方針で進めている。アプリのコードと違い、**インフラのコードは間違えると課金とデータ損失に直結する**ため、以下を守る。

### 16.1 `plan` の出力は必ず人間が読む

これが唯一かつ最大の安全弁である。AIが書いたコードを読むのが難しくても、**`plan` の出力は「何が作られ、何が消えるか」の平易な一覧**になっている。

特に次の2点は毎回確認する。

- **`Plan: X to add, Y to change, Z to destroy.` の `Z`。** 0でないなら、何が消えるかを読む
- **`-/+`（作り直し）の対象。** データベースやボリュームがこれになっていたら中身が消える

### 16.2 `-auto-approve` を使わない

```bash
terraform apply -auto-approve   # 確認なしで即実行。使わない
```

`apply` の確認プロンプトは、16.1で読んだ内容に納得してから進むための仕組みである。**AIにコマンドを実行させる場合、このフラグを付けさせない。**

### 16.3 `destroy` は意図を確認してから

`terraform destroy` は、AIが「片付けておきますね」と善意で実行しうるコマンドである。事前に `terraform plan -destroy` で対象を確認し、**消してよいと判断してから**実行する。

### 16.4 消えては困るリソースには `prevent_destroy`

```hcl
resource "aws_s3_bucket" "tfstate" {
  bucket = "example-terraform-state"

  lifecycle {
    # このリソースを削除しようとする plan/apply をエラーで止める
    prevent_destroy = true
  }
}
```

state保管用のS3バケット（[11.3](./03-state.md#113-鶏と卵stateを置くバケットは誰が作るのか)）のように、**失うと復旧が極めて困難なもの**に付ける。付けたうえで `destroy` しようとすると、Terraformがエラーで止めてくれる。

### 16.5 少しずつ適用する

一度に大量のリソースを定義して `apply` すると、途中で失敗したときに「どこまでできてどこから失敗したか」が分かりにくくなる。**ネットワーク → データベース → アプリ、のように段階を分けて `apply` し、都度動作を確認する**ほうが、結果的に速い。

### 16.6 コンソールで手作業しない

`plan` は「コードとstate」を基準に差分を出す。コンソールで手作業した変更はstateに反映されないため、**次の `apply` で意図せず元に戻される**ことがある。IaCを採用したら、変更経路をTerraformに一本化する。

---

[← Terraform学習ドキュメントトップへ戻る](./README.md)
