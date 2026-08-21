# インストールと基本ワークフロー

[← Terraform学習ドキュメントトップへ戻る](./README.md)

> 本ドキュメントにおける **5〜8章** をまとめています。

---

## 5. WSL2へのインストール

### 5.1 HashiCorp公式のaptリポジトリを使う

Ubuntuの標準リポジトリにTerraformは含まれていない。HashiCorpが提供する公式のaptリポジトリを登録して入れる。

```bash
# 1. 前提パッケージ
sudo apt update && sudo apt install -y gnupg software-properties-common curl

# 2. HashiCorpのGPG公開鍵を登録する
#    （パッケージが確かにHashiCorp製で、改ざんされていないことをaptが検証できるようにする）
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 3. リポジトリを登録する（signed-by で、上の鍵で署名されたものだけを信頼する）
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# 4. インストール
sudo apt update && sudo apt install -y terraform
```

`$(lsb_release -cs)` はUbuntuのコードネームに展開される（Ubuntu 22.04なら `jammy`）。`lsb_release` が無い環境では `sudo apt install -y lsb-release` を先に実行するか、`jammy` を直接書く。

### 5.2 確認

```bash
terraform version
# Terraform v1.15.9
# on linux_amd64
```

> 上記のバージョン番号は本ドキュメント作成時点（2026-08-21）に確認した最新版であり、参考値である。

### 5.3 複数バージョンを使い分けたくなったら

プロジェクトごとにTerraformのバージョンを固定したい場合は、`tfenv`（バージョン管理ツール）を使う方法がある。本プロジェクトはTerraformを使うのが初めてで、扱うバージョンも1つなので、当面はaptで入れた1つで足りる。

---

## 6. 基本の4コマンド

Terraformの操作は、実質この4つのコマンドに集約される。**それぞれが何をするかを正確に知っていることが、事故を防ぐ最大の要素**なので、丁寧に押さえる。

### 6.1 `terraform init` — 作業ディレクトリの初期化

```bash
terraform init
```

やっていること：

1. `.tf` ファイルを読み、必要なプロバイダ（`hashicorp/aws` など）を特定する
2. プロバイダのバイナリを Terraform Registry からダウンロードし、`.terraform/` に置く
3. 取得したバージョンを `.terraform.lock.hcl` に記録する
4. バックエンド（stateの保管先。[11章](./03-state.md#11-s3バックエンドと状態ロック)）を設定する

**AWSには一切変更を加えない。** 新しくクローンしたとき、プロバイダを追加したとき、バックエンド設定を変えたときに実行する。

### 6.2 `terraform plan` — 差分の確認

```bash
terraform plan
```

やっていること：

1. AWSに問い合わせて、いまリソースがどうなっているかを取得する（**読み取りのみ**）
2. コードに書かれた「あるべき状態」と突き合わせる
3. 差を埋めるために必要な操作の一覧を表示する

出力の記号が最も重要な情報である。

| 記号 | 意味 | 注意度 |
| --- | --- | --- |
| `+` | 作成される | |
| `~` | 更新される（リソースは残る） | |
| `-` | **削除される** | 高 |
| `-/+` | **いったん削除して作り直される** | **最高** |

`-/+`（replace）は特に危険で、たとえばデータベースがこれになっていたら**中のデータが消える**。plan出力の末尾に必ず出る次の行を、毎回読むこと。

```
Plan: 3 to add, 1 to change, 0 to destroy.
```

**`to destroy` が0でないときは、何が消えるのかを必ず確認する。**

### 6.3 `terraform apply` — 適用

```bash
terraform apply
```

`plan` を実行したうえで、内容を表示し、`yes` の入力を求めてから実行する。この確認プロンプトが最後の砦なので、**`-auto-approve` を安易に付けない**（[16章](./04-project-conventions.md#16-aiにterraformを書かせるときの安全策)）。

### 6.4 `terraform destroy` — 全削除

```bash
terraform destroy
```

**stateで管理しているリソースをすべて削除する。** コストを止める最も確実な手段であると同時に、最も危険なコマンドでもある。

事前に何が消えるかを確認するには：

```bash
terraform plan -destroy
```

### 6.5 典型的な1サイクル

```bash
terraform init                 # 最初の1回（構成を変えたら再度）
terraform plan                 # 差分を読む
terraform apply                # 差分を適用する
# ... 動作確認 ...
terraform plan -destroy        # 何が消えるか確認する
terraform destroy              # 片付ける
```

---

## 7. AWS認証情報の渡し方

### 7.1 `.tf` に書いてはいけない

AWSプロバイダは、次のように認証情報を直接受け取ることが**できてしまう**。

```hcl
# 絶対にこう書かないこと
provider "aws" {
  access_key = "AKIA..."
  secret_key = "wJalrXUt..."
}
```

`.tf` ファイルはGitでバージョン管理する対象である。ここに秘密を書くと、**コミットした瞬間に履歴へ永久に残る**。あとから削除しても、履歴を書き換えない限り取り出せてしまう。

### 7.2 正しい渡し方

Terraformは、AWS CLIと**同じ仕組み**で認証情報を探す（[docs/aws/02-cli-setup.md 6.5](../aws/02-cli-setup.md#65-認証情報が読まれる順番)）。つまり `aws configure` を済ませてあれば、`.tf` 側には何も書かなくてよい。

```hcl
provider "aws" {
  region = "ap-northeast-1"   # リージョンだけ書く。認証情報は書かない
}
```

プロファイルを使い分ける場合は、コマンド実行時に環境変数で指定する。

```bash
AWS_PROFILE=personal terraform plan
```

**「どのアカウントに対して実行しているか」を取り違えるのはクラウドで最も怖い事故の1つ**なので、複数アカウントを扱うようになったら `terraform plan` の前に `aws sts get-caller-identity` を確認する習慣をつけるとよい。

### 7.3 リージョンをコードに固定する意味

`provider "aws"` の `region` は、`.tf` に書いてよい（むしろ書くべき）情報である。手元の `~/.aws/config` の既定リージョン設定に依存させてしまうと、**設定が違う端末で実行したときに別のリージョンにリソースが作られる**。秘密でない設定はコードに固定し、秘密は環境から渡す、という切り分けになる。

---

## 8. バージョンの固定

インフラのコードは「半年後に同じ結果になること」が重要なので、Terraform本体とプロバイダのバージョンを明示的に縛る。

### 8.1 `required_version` と `required_providers`

```hcl
terraform {
  # Terraform本体のバージョン制約。これを満たさない環境では実行を拒否する
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.61"
    }
  }
}
```

`~>` は**悲観的バージョン制約**と呼ばれる書き方で、「一番右の桁だけ上げてよい」を意味する。

| 書き方 | 許容される範囲 |
| --- | --- |
| `~> 6.61` | `6.61` 以上 `7.0` 未満（マイナー・パッチ更新は許すが、メジャーは上げない） |
| `~> 6.61.0` | `6.61.0` 以上 `6.62.0` 未満（パッチ更新のみ許す） |
| `= 6.61.0` | 完全固定 |

破壊的変更が入るメジャーバージョンアップだけを止めたいので、`~> 6.61` 程度の指定が扱いやすい。

### 8.2 `.terraform.lock.hcl`

`terraform init` は、実際に取得したプロバイダのバージョンとチェックサムを `.terraform.lock.hcl` に記録する。npmの `package-lock.json` と同じ役割である。

**このファイルはコミットする。** コミットしておくと、別の端末やCIで `terraform init` したときにまったく同じバージョンのプロバイダが入り、「自分の環境では動くのに」が起きなくなる。

プロバイダを意図的に上げたいときは：

```bash
terraform init -upgrade
```

---

[← Terraform学習ドキュメントトップへ戻る](./README.md)
