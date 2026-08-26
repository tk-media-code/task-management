# infra/ — AWS環境の構築

このディレクトリは、タスク管理アプリをAWS上に構築するTerraformの構成です。

- **AWSというサービス自体の解説**は [docs/aws/](../docs/aws/README.md) を参照してください。
- **Terraformというツールの使い方**は [docs/terraform/](../docs/terraform/README.md) を参照してください。
- ここに書くのは、この構成を**実際に動かすための手順**です。

---

## この構成の前提

**スクールの課題として数日だけ公開し、そのあと `terraform destroy` で消す**ことを前提に設計しています。長期運用を想定した構成ではありません。

### 全体像

```
Internet ──HTTP(80)──▶ EC2 t3.micro (Amazon Linux 2023)
                        ├ 【ホスト】nginx
                        │   ├ /      → /var/www/dist/   （React のビルド成果物）
                        │   └ /api/  → 127.0.0.1:8080   （バックエンドへ中継）
                        └ 【Docker】backend コンテナ ×1
                                    │ 5432
                                    ▼
                        RDS db.t4g.micro (PostgreSQL 18)
                        プライベートサブネット / 外部から接続不可
```

フロントエンドは静的ファイルなのでコンテナ化せず、nginxが直接配信します。バックエンドだけをDockerコンテナとして動かす構成です。

### 意図的に実装していないもの

| 項目 | 理由 |
| --- | --- |
| **HTTPS** | 数日で消す環境のため。証明書の取得・更新の仕組みを持たない |
| **ベーシック認証** | 同上 |
| ALB（ロードバランサ） | 月18ドル程度かかる。nginxが同じ役割を果たせる |
| NAT Gateway | 月45ドル程度かかる。RDSは外部への発信をしないため不要 |
| Elastic IP | 停止・起動をしなければIPは変わらない。EIPは未使用時も課金される |
| ECR | イメージは `docker save` で直接転送すれば足りる |

> ⚠️ **要件定義8.2との乖離**
> [要件定義8.2](../docs/requirements/02-requirements.md) はベーシック認証とHTTPSを必須と定めていますが、上記のとおり今回は実装していません。
> **つまり、URLを知っている人は誰でもデータを作成・削除できる状態になります。**
> このため、投入するのは `db/seed/dummy-data.sql` のダミーデータだけにし、実際に使っているタスクのデータは入れないでください。
> 人に見せる必要がない間は、`http_allowed_cidrs` を自分のIPだけに絞ることができます。

---

## 初回セットアップ

### 1. SSH鍵を作る

```bash
ssh-keygen -t ed25519 -f ~/.ssh/task-management-ec2 -C "task-management deploy" -N ''
```

秘密鍵はローカルに置いたままにし、**公開鍵だけ**をTerraformがAWSに登録します。Terraformに鍵そのものを生成させると、秘密鍵がstateに平文で保存されてしまうため、この手順は手作業で行います。

### 2. 変数ファイルを用意する

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
cp infra/account/terraform.tfvars.example infra/account/terraform.tfvars
```

それぞれを編集します。必要な値は次のとおりです。

```bash
# 自分のグローバルIP（SSHの許可元に使う）
curl -s https://checkip.amazonaws.com

# DBのパスワード（英数字のみ。理由は variables.tf のコメント参照）
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24; echo
```

`*.tfvars` は `.gitignore` 済みでコミットされません。

---

## 構築の手順

**`terraform apply` は必ず `plan` の内容を読んでから実行してください。** `-auto-approve` は使いません（[運用ルール](../docs/terraform/04-project-conventions.md#16-aiにterraformを書かせるときの安全策)）。

### 段階を分ける理由

一度に全部applyすると、失敗したときに「どこまでできてどこから失敗したか」が分かりにくくなります。`.tf` ファイルを1つずつ足していけば、それがそのまま段階的なapplyになります（`-target` という機能もありますが、依存関係の一部だけを適用する危険な機能なので使いません）。

**ネットワークとセキュリティグループの段階は課金がゼロ**なので、ここで `plan` の読み方に慣れておくとよいです。

### Stage 1: 予算アラート

```bash
terraform -chdir=infra/account init
terraform -chdir=infra/account plan
terraform -chdir=infra/account apply
```

最初に作る理由は、**これ以降のどの段階で消し忘れが出ても、翌日には気づけるようになる**からです。

このディレクトリは本体（`infra/`）とstateを分けています。予算アラートは「アプリを消しても残っていてほしい唯一のリソース」であり、同じstateに置くと `destroy` で一緒に消えて、消し忘れに気づく手段そのものが失われるためです。

apply後、AWSから購読確認のメールが届きます。

### Stage 2〜5: 本体

```bash
terraform -chdir=infra init
terraform -chdir=infra plan      # 何が作られるかを読む
terraform -chdir=infra apply
```

`plan` を読むときに特に見るべき点：

- `Plan: X to add, Y to change, Z to destroy.` の **Z**。0でなければ何が消えるのかを確認する
- **`-/+`（作り直し）** の対象。DBやボリュームがこれになっていたら中身が消える

### 構築後の確認

```bash
terraform -chdir=infra output          # 接続情報の一覧
IP=$(terraform -chdir=infra output -raw ec2_public_ip)

# EC2に入り、初期化の完了を待つ（初回は数分かかる）
ssh -i ~/.ssh/task-management-ec2 ec2-user@$IP 'sudo cloud-init status --wait'

# ★ アプリを動かす前に、まずここでDBへの到達性だけを確定させる
ssh -i ~/.ssh/task-management-ec2 ec2-user@$IP
psql -h <RDSのホスト名> -U taskuser -d taskmanagement -c 'select version();'
```

**この `psql` が通ることを、コンテナを起動する前に必ず確認してください。** これが通れば「セキュリティグループ・サブネット・接続情報」の3つが正しいと確定します。先にアプリを起動してしまうと、起動失敗の原因が「ネットワークの問題」「認証情報の問題」「コンテナの問題」のどれなのか切り分けられなくなります。

| 症状 | 原因 |
| --- | --- |
| 応答がなく固まる | RDS側のSGがEC2のSGを参照していない／サブネットグループの指定が違う |
| `could not translate host name` | VPCの `enable_dns_hostnames` が false |
| `password authentication failed` | tfvarsの値と打ち込んだ値が違う |

---

## アプリケーションの配置

インフラが構築できたら、`scripts/deploy.sh` でアプリを配置します。

```bash
bash scripts/deploy.sh --all     # 画面とAPIをまとめて配置する
bash scripts/deploy.sh --web     # 画面とnginx設定だけ
bash scripts/deploy.sh --backend # APIコンテナだけ
bash scripts/deploy.sh --seed    # ダミーデータを投入する（既存データは消える）
```

接続先のIPアドレスやDBのパスワードは `terraform output` から自動で読み取るため、手で打ち込む必要はありません。

### ビルドをローカルで行う理由

EC2はt3.micro（メモリ1GB）で、GradleもViteもビルドに1GB前後を要求するため、**サーバー上ではビルドできません**。ローカルでビルドし、成果物だけを転送します。

| 対象 | 転送するもの | 手段 |
| --- | --- | --- |
| frontend | `dist/`（数MB） | `rsync --delete` |
| backend | Dockerイメージ（圧縮後およそ170MB） | `docker save \| ssh 'docker load'` |

ECRを使っていないのは、この方法で足りるためです。使う場合はECRリポジトリとIAMインスタンスプロファイルの作成が追加で必要になります。

なお、フロントエンドのビルドは**コンテナ内**で実行します（`docker exec ... npm run build`）。`frontend/dist/` はコンテナが作ったディレクトリでroot所有のため、ホスト側から書き込めないためです。

### 投入する順序

**`--seed` は必ず `--backend` の後に実行してください。**

`db/seed/dummy-data.sql` はDMLだけを含んでおり、テーブルを作りません。テーブルは backend の起動時に `spring.jpa.hibernate.ddl-auto=update` が作るため、先にコンテナを起動しておく必要があります。順序を逆にすると `relation "board" does not exist` で失敗します。

`--all` に `--seed` を含めていないのは、このSQLが冒頭で `TRUNCATE` を実行し、既存のデータをすべて消すためです。

### 配置後の確認

```bash
IP=$(terraform -chdir=infra output -raw ec2_public_ip)

curl -s -o /dev/null -w '%{http_code}\n' "http://$IP/"           # 200
curl -s -o /dev/null -w '%{http_code}\n' "http://$IP/boards/1"   # 200（SPAフォールバック）
curl -s "http://$IP/actuator/health"                              # {"status":"UP"}
curl -s "http://$IP/api/boards"                                   # ボードのJSON
curl --max-time 5 "http://$IP:8080/"                              # 接続不可であること
```

**`/boards/1` への直接アクセスは必ず確認してください。** SPAフォールバックの設定を忘れると、「トップページから画面遷移する分には動くのに、その画面でリロードすると404になる」という分かりにくい壊れ方をします。

### うまくいかないときは

| 症状 | 確認すること |
| --- | --- |
| 502 Bad Gateway | コンテナが起動しているか。`docker logs task-management-backend` |
| APIだけ404 | nginxの `proxy_pass` の末尾にスラッシュが付いていないか |
| 既定のページが出る | `/etc/nginx/nginx.conf` が置き換わっているか。`sudo nginx -t` |
| リロードで404 | SPAフォールバック（`try_files`）の設定 |
| 画面が古いまま | `index.html` のキャッシュ。ハードリロードで確認する |

---

## 片付け（destroy）

**課金を止める最も確実な方法は、リソースを消すことです。**

```bash
# 1. 何が消えるかを先に読む
terraform -chdir=infra plan -destroy

# 2. 実行する
terraform -chdir=infra destroy

# 3. stateが空になったことを確認する
terraform -chdir=infra state list
```

### 消し忘れの確認

destroyが途中で失敗して一部だけ残ることがあります。全リソースに `Project` タグを付けてあるので、これで横断的に探せます。

```bash
R=ap-northeast-1
aws ec2 describe-instances --region $R \
  --filters "Name=tag:Project,Values=task-management" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].InstanceId'
aws rds describe-db-instances --region $R --query 'DBInstances[].DBInstanceIdentifier'
aws rds describe-db-snapshots --region $R --snapshot-type manual --query 'DBSnapshots[].DBSnapshotIdentifier'
aws ec2 describe-volumes --region $R --filters Name=status,Values=available --query 'Volumes[].VolumeId'
aws ec2 describe-addresses --region $R --query 'Addresses[].PublicIp'
```

すべて空（`[]`）であれば完了です。

**予算アラート（`infra/account/`）は消しません。** destroyの対象外です。

翌日、実際に課金が止まったかを確認します。

```bash
aws ce get-cost-and-usage --time-period Start=<destroyの前日>,End=<翌々日> \
  --granularity DAILY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE
```

---

## ファイル構成

| ファイル | 内容 |
| --- | --- |
| `providers.tf` | プロバイダとバージョンの固定、全リソース共通のタグ |
| `variables.tf` | 入力変数の宣言。SSHの全開放とパスワードの記号を機械的に禁止している |
| `network.tf` | VPC・サブネット・ルートテーブル・DBサブネットグループ |
| `security.tf` | セキュリティグループ・キーペア |
| `compute.tf` | AMIの検索とEC2 |
| `database.tf` | RDS |
| `outputs.tf` | 接続情報の出力 |
| `files/user-data.sh` | EC2の初回起動時に流れる初期化スクリプト |
| `account/` | 予算アラート（本体とstateを分けている） |
