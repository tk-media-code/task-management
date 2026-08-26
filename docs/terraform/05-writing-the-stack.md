# 実際に書いてみて分かったこと

[← Terraform学習ドキュメントトップへ戻る](./README.md)

> 本ドキュメントにおける **17〜22章** をまとめています。

> **この章の位置づけ**：[1〜16章](./README.md)は「Terraformとは何か」「どう使うか」という準備でした。ここからは、[infra/](../../infra/README.md) に実際のインフラを書いたときに使った機能と、そこで分かったことを扱います。

---

## 17. data ソース

### 17.1 「作る」ではなく「調べる」ブロック

`resource` がリソースを作るのに対し、**`data` は既にあるものを調べます**。何も作らず、何も変更しません。

```hcl
# 使用可能なAZを問い合わせる
data "aws_availability_zones" "available" {
  state = "available"
}

# 参照するときは data. を付ける
availability_zone = data.aws_availability_zones.available.names[0]
```

これによって、環境ごとに変わる値をコードに直接書かずに済みます。

### 17.2 AMI IDを直接書かない理由

AMI（OSのテンプレート）のIDは、**リージョンごとに異なり、AWSが更新するたびに変わります**。`ami-0abc123...` とコードに書くと、別のリージョンでは動かず、時間が経つと古いOSを使い続けることになります。

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```

`owners` の指定は省略できません。同じような名前のAMIを第三者が公開している可能性があるため、**「AWS公式のものだけ」に絞る**必要があります。

### 17.3 `most_recent = true` が招く「applyのたびに作り直し」

これは実際に対処が必要になった問題です。

`most_recent = true` は「最新のものを選ぶ」という意味です。AWSがAmazon Linuxの新しいAMIを公開すると、**次に `plan` を実行したときに「AMIが変わった」という差分が出ます**。そしてAMIの変更はインスタンスの再作成を伴うため、`-/+`（作り直し）になります。

つまり、**何も変更していないのに、AWSの都合でサーバーが作り直される計画が出てくる**わけです。

```hcl
lifecycle {
  ignore_changes = [ami]
}
```

`ignore_changes` は「この属性の差分は無視する」という指定です。一度立てたインスタンスを、AMIの更新だけを理由に作り直させないようにします。

> **`lifecycle` は「Terraformの管理の仕方」を制御するブロック**で、AWS側に送られる設定ではありません。他に `prevent_destroy`（削除を拒否する）や `create_before_destroy`（作ってから消す）があります。

### 17.4 SSMパラメータという別の方法

AMIの取得には、AWSが公開しているSSMパラメータを使う方法もあります。

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
```

名前で一意に決まるので、`filter` の書き方を誤って別のAMIを掴む心配がありません。ただし**返り値がsensitive扱いになり、`plan` の出力でAMI IDが伏せられる**ため、「どのAMIが選ばれたのか」を確認しづらくなります。今回は確認しやすさを優先して `aws_ami` を使いました。

---

## 18. リソース間の参照と依存関係

### 18.1 参照するだけで順序が決まる

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id     # ← VPCを参照している
}
```

この `aws_vpc.main.id` という記述だけで、Terraformは「**VPCを作ってからサブネットを作る**」という順序を理解します。これを**暗黙の依存関係**と呼びます。

順序を自分で書く必要はありません。宣言的であるとは、こういうことです。「何を作るか」を書けば、「どの順で作るか」はTerraformが決めます。

### 18.2 依存関係は並列実行にも効く

依存関係のないリソースは**同時に作られます**。今回のapplyでも、VPCの作成後、サブネット・ルートテーブル・IGWが並行して作られました。

そのため、apply中のログは書いた順に流れるとは限りません。これは異常ではありません。

### 18.3 depends_on が必要になる場合

参照関係がないのに順序を守らせたい場合だけ、明示的に書きます。

```hcl
depends_on = [aws_internet_gateway.main]
```

ただし**多用は避けます**。参照で表現できるものは参照で書くほうが、意図が明確になるためです。今回の構成では一度も使いませんでした。

---

## 19. 段階的なapplyの実践

### 19.1 ファイルを分けることは「凝った構成」ではない

[13.2](./04-project-conventions.md#132-中身はまだ作らない)で「最初からモジュール化や環境別の分割をしない」と決めましたが、**同一ディレクトリ内で `.tf` ファイルを複数に分けることは、これに当たりません**。

Terraformは同じディレクトリの `.tf` を**すべて読み込んで連結して扱います**。ファイル分割は人間が読みやすくするためのもので、構造上の意味はありません。

### 19.2 ファイルを1つずつ足すと、それが段階的applyになる

[16.5](./04-project-conventions.md#165-少しずつ適用する)の「少しずつ適用する」を、`-target` を使わずに実現できます。

| 段階 | 置くファイル | 作られるもの | 課金 |
| --- | --- | --- | --- |
| 1 | `account/` | 予算アラート | なし |
| 2 | `network.tf` | VPC・サブネット・IGW・ルートテーブル | **なし** |
| 3 | `security.tf` | セキュリティグループ・キーペア | **なし** |
| 4 | `compute.tf` | EC2 | あり |
| 5 | `database.tf` | RDS | あり |

**段階2と3は課金がゼロ**です。ここで `plan` の読み方に慣れておくと、課金が始まる段階で落ち着いて判断できます。何度applyしてもdestroyしても、費用は発生しません。

### 19.3 `-target` を使わない理由

`terraform apply -target=aws_vpc.main` のように、対象を絞る機能があります。しかし**依存関係の一部だけを適用する危険な機能**であり、公式ドキュメントも例外的な状況のためのものだと述べています。

ファイルを足していく方式なら、`plan` は常に「今あるコード全体」に対する差分を示します。状態が分かりやすく保たれます。

### 19.4 plan の出力の読み方

```
Plan: 11 to add, 0 to change, 0 to destroy.
```

見るべき記号は次のとおりです。

| 記号 | 意味 | 注意度 |
| --- | --- | --- |
| `+` | 作成される | |
| `~` | 変更される（作り直しはしない） | |
| `-` | 削除される | **高** |
| `-/+` | **作り直される**（一度消してから作る） | **最高** |

**`-/+` が最も危険です。** データベースやボリュームがこれになっていたら、**中身が消えます**。

`(known after apply)` は「まだ分からない」という意味です。作成前のリソースのIDを参照している場合に出るもので、異常ではありません。

### 19.5 実際の段階的applyの記録

今回の構築では、以下のように進みました。

```
Stage 1: Plan: 1 to add   → 予算アラート
Stage 2: Plan: 11 to add  → ネットワーク（課金なし）
Stage 3: Plan: 7 to add   → SG・キーペア（課金なし）
Stage 4: Plan: 1 to add   → EC2
Stage 5: Plan: 1 to add   → RDS
```

すべての段階で `0 to change, 0 to destroy` でした。**既存のものに一切触れずに積み上げられている**ことが、この数字から確認できます。

なお、Stage 3で `description` に日本語を書いていたためapplyが途中で失敗しましたが、**成功した分はstateに記録されているため、修正後に再実行すると残りだけが適用されました**（`Plan: 1 to add`）。これがstateを持つことの利点です。

---

## 20. file と templatefile、そして user_data

### 20.1 3つの関数の違い

| 関数 | 用途 |
| --- | --- |
| `file(path)` | ファイルの中身をそのまま文字列として読む |
| `templatefile(path, vars)` | ファイルを読み、`${...}` を変数で置き換える |
| `pathexpand(path)` | `~` をホームディレクトリに展開する |

### 20.2 `file("~/...")` はエラーになる

```hcl
public_key = file("~/.ssh/task-management-ec2.pub")            # エラー
public_key = file(pathexpand("~/.ssh/task-management-ec2.pub")) # 正しい
```

Terraformの `file()` は `~` を展開しません。シェルが展開しているだけで、Terraform自身にその機能はないためです。**`pathexpand()` で明示的に展開**します。

### 20.3 user_data は変更しても反映されない

これは挙動を知らないと必ず詰まる点です。

user_dataは**インスタンスの初回起動時に一度だけ実行**されます。内容を変更しても、

- 動いているインスタンスの中で再実行されることはない
- **既定では、Terraformが差分を検出してもインスタンスを作り直さない**

つまり、**スクリプトを直しても何も起きません**。「直したのに反映されない」という、最も分かりにくい形で詰まります。

```hcl
user_data_replace_on_change = true
```

これを指定すると、user_dataの変更が `plan` に **`-/+`（作り直し）** として現れます。反映するにはインスタンスの作り直しが必要だ、という事実が可視化されます。

### 20.4 設定ファイルをTerraformに持たせるか、別経路で配るか

今回、EC2に置くファイルを2種類に分けました。

| ファイル | 配置方法 | 理由 |
| --- | --- | --- |
| `user-data.sh` | Terraform（`file()`） | OSに何を入れるか。一度決めたら変えない |
| `nginx.conf` | `scripts/deploy.sh` が scp | **何度も直すもの**だから |

判断基準は「**変更の頻度**」です。

user_dataに含めると、修正のたびに**インスタンスの作り直し**（IPも変わり、アプリも再デプロイ）が必要になります。nginxの設定は試行錯誤するものなので、これでは苦痛です。scpで配れば `nginx -t` で検証して `reload` するだけ、数秒で済みます。

> 加えて、**認証情報の類は絶対にuser_dataに入れません**。user_dataはインスタンスメタデータから読み取れるため、EC2にアクセスできる人には見えてしまいます。stateにも平文で入ります。

---

## 21. 機密情報の扱い（実践編）

### 21.1 stateに平文で入る、を実際に確認する

[12章](./03-state.md#12-stateに機密が平文で入るということ)で扱ったとおり、`sensitive = true` を付けても**stateには平文で保存されます**。

```bash
grep -o '"password": "[^"]*"' infra/terraform.tfstate
```

実際に実行すると、DBのパスワードがそのまま読めます。`sensitive` は**画面やログに出さないための機能**であって、暗号化ではありません。

だからこそ `.gitignore` で `*.tfstate` を除外することが、他の何より重要になります。

### 21.2 sensitiveなoutputをスクリプトから読む

```hcl
output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

`sensitive = true` を付けたoutputは `terraform output` の一覧に `<sensitive>` と表示されますが、名前を指定すれば取り出せます。

```bash
terraform output -raw db_password
```

一見すると危険に思えますが、**この値はstateに既に平文で入っている**ため、outputにしたことで新たな漏洩経路が増えるわけではありません。

むしろ利点があります。デプロイスクリプトがここから読むようにすれば、**人がパスワードを手で打ち写す工程がなくなります**。接続できない原因の大半は打ち間違いなので、実質的にはこちらのほうが安全です。

### 21.3 tls_private_key を使ってはいけない

Terraformには秘密鍵を生成する `tls_private_key` リソースがありますが、**生成された秘密鍵はstateに平文で保存されます**。

SSHの鍵は `ssh-keygen` でローカルに作り、**公開鍵だけをTerraformに渡す**のが正しい形です。

### 21.4 validationで機械的に防ぐ

変数には検証ルールを書けます。

```hcl
variable "ssh_allowed_cidr" {
  type = string

  validation {
    condition     = var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "SSHを 0.0.0.0/0 に開けることはできません。"
  }
}
```

「気をつける」という人間の注意力に頼らず、**コードで機械的に止める**ほうが確実です。今回は他に、DBのパスワードを英数字のみに制限しています。

```hcl
condition = can(regex("^[A-Za-z0-9]{16,41}$", var.db_password))
```

記号を禁じている理由は3つ重なっています。

1. RDSがマスターパスワードに `/`・`@`・`"`・空白を許可していない
2. 同じ値を書いたファイルを、Dockerの `--env-file` が読む（クォートを値の一部として扱う）
3. **同じファイルをシェルの `source` でも読む（クォートを外して解釈する。2と正反対）**

英数字だけに制限すれば、3者すべてで同じ値として扱われます。

### 21.5 より進んだ選択肢

今回は使いませんでしたが、stateに機密を入れない方法もあります。

| 方法 | 内容 | コスト |
| --- | --- | --- |
| `manage_master_user_password = true` | AWSがパスワードを生成しSecrets Managerで管理する | シークレット1つあたり月$0.40程度 |
| write-only引数（`password_wo`） | applyのときだけ値を送り、stateに保存しない（Terraform 1.11以降） | なし |

前者はEC2側にSecrets Managerを読むIAMロールが必要になり、構成が一段複雑になります。単独作業・短期間という前提では過剰と判断しました。

---

## 22. default_tags と後片付け

### 22.1 全リソースに自動でタグを付ける

```hcl
provider "aws" {
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
```

このプロバイダで作る**すべてのリソースに、自動でタグが付きます**。リソースごとに `tags` を書く方式だと必ず付け忘れが出ますが、この方式なら漏れません。

### 22.2 タグは後片付けのために効く

タグの本当の価値は、**destroyのあとに現れます**。

`terraform destroy` が途中で失敗して一部のリソースが残ることがあります。そのとき、タグで横断的に検索できます。

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=task-management" \
  --query 'Reservations[].Instances[].InstanceId'
```

タグがないと、コンソールを1サービスずつ見て回ることになります。**消し忘れは課金に直結する**ので、この差は小さくありません。

### 22.3 destroyの手順

```bash
# 1. 何が消えるかを先に読む
terraform -chdir=infra plan -destroy

# 2. 実行する（-auto-approve は使わない）
terraform -chdir=infra destroy

# 3. stateが空になったことを確認する
terraform -chdir=infra state list
```

`state list` が何も出力しなければ、Terraformの管理下にリソースは残っていません。

### 22.4 消し忘れを確認する対象

stateが空でも、Terraform管理外で作られたものは残ります。特に次を確認します。

| 対象 | なぜ残るか |
| --- | --- |
| EBSボリューム | `delete_on_termination = false` だとインスタンスを消しても残る |
| RDSスナップショット | `skip_final_snapshot = false` だとdestroy時に自動で作られる |
| Elastic IP | 紐づけを解除しても解放しない限り残る（**未使用でも課金される**） |
| CloudWatch Logs | 既定の保持期間が「無期限」 |

### 22.5 ライフサイクルでstateを分ける

今回、予算アラートだけを `infra/account/` として別のstateにしました。

理由は、**アプリを消しても残っていてほしい唯一のリソース**だからです。同じstateに置くと `terraform destroy` で一緒に消え、「消し忘れに気づくための仕組み」そのものが失われます。

これは環境ごとの分割（dev/prod）ではなく、**ライフサイクルによる分割**です。[13.2](./04-project-conventions.md#132-中身はまだ作らない)が戒める「凝った構成」には当たりません。1ファイル1リソースなので負担もありません。

> **stateを分ける判断基準は「一緒に消えてよいか」です。** 一緒に作り、一緒に消すものは同じstateに。片方だけ残したいものは別のstateに。

---

[← Terraform学習ドキュメントトップへ戻る](./README.md)
