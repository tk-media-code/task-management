# AWS CLIのセットアップ（WSL2）

[← AWS学習ドキュメントトップへ戻る](./README.md)

> 本ドキュメントにおける **5〜8章** をまとめています。

---

## 5. AWS CLI v2のインストール

### 5.1 なぜWSL2（Linux側）に入れるのか

本プロジェクトの開発環境はWindows上のWSL2（Ubuntu 22.04）で、Docker・git・Claude Codeもすべてこの中で動いている。AWS CLIをWindows側に入れると、**WSL側のシェルからは呼べない**（正確には `aws.exe` として呼べなくはないが、パスの解釈が Windows形式 と Linux形式 で食い違い、認証情報ファイルの位置もずれる）。

ツールの実行主体と同じ場所に置くのが素直なので、**WSL2側に直接インストールする**。

### 5.2 インストール

AWS CLI v2 は Ubuntu の `apt` では配布されていない（`apt install awscli` で入るのは古いv1系）。公式のインストールスクリプトを使う。

```bash
# 現在の利用者のみにインストール（$HOME/.local 配下。sudo不要）
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
```

システム全体（`/usr/local/aws-cli`）に入れる場合は `--system` を渡す。

```bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | sudo bash -s -- --system
```

> **バージョンを固定したい場合**は、zipをダウンロードして展開する従来の方式を使う。`install.sh` は常に最新版を取ってくるため、バージョンを揃えたいチーム運用には向かない。
>
> ```bash
> curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
> unzip awscliv2.zip
> sudo ./aws/install
> ```

### 5.3 スクリプトをパイプで直接実行しない

上のコマンドは `curl ... | bash` の形になっており、**ダウンロードしたものを中身を見ないまま実行する**ことになる。配布元が公式であっても、実行前に一度保存して目を通す習慣をつけたほうがよい。

```bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh -o aws-install.sh
less aws-install.sh    # 何をするスクリプトかを確認する
bash aws-install.sh
```

このスクリプトは、**ダウンロードしたzipのPGP署名を検証してからインストールする**（AWSの公開鍵がスクリプト内に直接埋め込まれており、外部から鍵を取りに行かない）。成功すると次の行が出る。

```
GPG signature verified.
```

ただし**`gpg` コマンドが入っていない環境では、検証をスキップして警告を出すだけで先に進む**。

```
gpg not found; skipping signature verification. Install gnupg for stronger verification.
```

「エラーにならない」ため見落としやすい。**先に `gpg`（`gnupg` パッケージ）を入れておくこと。**

### 5.4 どこに何が入るのか

`--system` を付けない場合、インストール先は**XDG Base Directory仕様**に従った次の場所になる。

| 場所 | 中身 |
| --- | --- |
| `~/.local/share/aws-cli` | 本体（Pythonランタイムを同梱するため**271MBほどある**） |
| `~/.local/bin/aws` | 本体へのシンボリックリンク。実際に呼ばれるのはこれ |
| `~/.local/bin/aws_completer` | シェル補完用。同じくシンボリックリンク |

```bash
$ ls -l ~/.local/bin/aws
lrwxrwxrwx ... /home/tokuoka/.local/bin/aws -> /home/tokuoka/.local/share/aws-cli/v2/current/bin/aws
```

Ubuntuの `~/.profile` には「`~/.local/bin` が存在すればPATHに追加する」という記述が最初から入っているため、**PATHの設定は不要**なことが多い。`which aws` が何も返さない場合のみ、ログインし直すかPATHに追加する。

インストール時の情報は `install.json` に記録され、次節の `aws update` がこれを読んで「どこに・どの方式で入れたか」を判別する。

```json
{
  "distribution_source": "script-exe",
  "install_dir": "/home/tokuoka/.local/share/aws-cli",
  "bin_dir": "/home/tokuoka/.local/bin",
  "script_install": { "system": false, "version_resolved": "2.36.31", "quiet": false }
}
```

### 5.5 確認と更新

```bash
aws --version
# aws-cli/2.36.31 Python/3.14.6 Linux/5.15.167.4-microsoft-standard-WSL2 script-exe/x86_64.ubuntu.22
```

末尾の `script-exe` は**インストール方式**を表す。zipを展開する従来方式なら `exe`、このインストールスクリプト経由なら `script-exe` になる。

更新は `aws update` で行う。前節の `install.json` を読んで、**最初と同じ方式・同じ場所**に最新版を入れ直すため、ユーザーインストールなら更新時もsudoは不要である（`--system` で入れた場合は更新時もsudoが要る）。

```bash
aws update
```

同じバージョンが既に入っている場合は `nothing to do.` と表示して何もしない。なお、install.shを再実行しても更新になる（新しいバージョンがあれば `Installing AWS CLI 2.36.31 → 2.37.0` のように差分が表示される）が、**ダウングレードは拒否される**。

> 上記のバージョン番号は2026-08-26に実際にインストールしたときの値である。実行した時点の最新版が入るため、同じにはならない。

---

## 6. 認証情報の保存場所とプロファイル

### 6.1 設定コマンド

[3章](./01-account-setup.md#3-アクセスキーの発行と取り扱い)で発行したアクセスキーを、対話形式で登録する。

```bash
aws configure
# AWS Access Key ID [None]: AKIA...
# AWS Secret Access Key [None]: ...
# Default region name [None]: ap-northeast-1
# Default output format [None]: json
```

### 6.2 どこに保存されるか

`aws configure` は入力内容を2つのファイルに分けて書き込む。**この分割には意味がある。**

| ファイル | 内容 | 性質 |
| --- | --- | --- |
| `~/.aws/credentials` | アクセスキーID・シークレットアクセスキー | **秘密**。絶対に共有しない |
| `~/.aws/config` | 既定リージョン・出力形式など | 秘密ではない。共有しても実害はない |

```ini
# ~/.aws/credentials
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

```ini
# ~/.aws/config
[default]
region = ap-northeast-1
output = json
```

秘密の値だけを1ファイルに隔離しておくと、「このファイルは絶対に外に出さない」という扱いが単純明快になる。設定と機密を混ぜないのは、本プロジェクトが `.env`（コミットしない）と `.env.example`（コミットする）を分けているのと同じ発想である。

### 6.3 パーミッション

`~/.aws` は自分だけが読める状態にしておく。

```bash
chmod 700 ~/.aws
chmod 600 ~/.aws/credentials
```

`700` は「所有者は読み書き実行できるが、グループ・その他は何もできない」、`600` は「所有者だけが読み書きできる」を意味する。

> **WindowsのファイルシステムにAWSの認証情報を置かない。** `/mnt/c/...` 配下（WindowsのCドライブ）はWSLから見ると常にパーミッション `777`（誰でも読み書き可能）として見え、`chmod` が効かない。認証情報はLinux側の `~/.aws` に置くこと。

### 6.4 プロファイル（複数の認証情報の使い分け）

1つの端末から複数のAWSアカウントを扱いたくなったら、**プロファイル**で名前を付けて分ける。

```ini
# ~/.aws/credentials
[default]
aws_access_key_id = ...

[personal]
aws_access_key_id = ...
```

使うときは `--profile` を付けるか、環境変数 `AWS_PROFILE` で切り替える。

```bash
aws sts get-caller-identity --profile personal
AWS_PROFILE=personal terraform plan
```

本プロジェクトでは当面アカウントが1つなので `default` のみで足りるが、**「操作対象のアカウントを取り違える」のはクラウドで最も怖い事故の1つ**なので、複数アカウントを扱い始めたら早めにプロファイルを分けること。

### 6.5 認証情報が読まれる順番

AWS CLIとTerraformは、認証情報を次の優先順位で探す。上にあるものが勝つ。

1. コマンドライン引数（`--profile` など）
2. 環境変数（`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_PROFILE`）
3. `~/.aws/credentials`・`~/.aws/config`
4. EC2インスタンスプロファイル／ECSタスクロール（AWS上で動いている場合）

「設定したはずのキーと違うものが使われている」ときは、**環境変数が残っていないか**をまず疑う。4番目は、AWS上で動くアプリが**アクセスキーを一切持たずに**AWSのAPIを呼べる仕組みで、本番環境では原則こちらを使う（キーを配置しなくてよいぶん、漏洩の可能性そのものが無くなる）。

### 6.6 AIエージェントに認証情報を扱わせない

本プロジェクトはClaude Codeを使って開発しており、AIがシェルコマンドを実行する場面が多い。そのなかで、**`aws configure` によるキーの登録だけは人間が自分の手で実行する。**

理由は[3.3の鉄則](./01-account-setup.md#33-取り扱いの鉄則)そのものである。AIにキーを設定させるには、プロンプトに書くか、AIが実行するコマンドの引数に書くしかない。どちらも**会話ログに平文で残る**。ログの保存先や保存期間を自分で管理できない以上、「渡さない」以外に安全側の選択肢がない。

一方、**設定済みかどうかの確認はAIに任せてよい。** `aws configure list` はキーを末尾4文字しか表示しないためである。

```bash
$ aws configure list
      Name       : Value              : Type                    : Location
   access_key    : ****************UXNP : shared-credentials-file :
   secret_key    : ****************b2oQ : shared-credentials-file :
       region    : ap-northeast-1     : config-file             : ~/.aws/config
```

疎通確認に使う `aws sts get-caller-identity`（[7章](#7-疎通確認)）は12桁のアカウントIDを出力する。アカウントIDは単体で悪用できるものではないが、会話ログに残したくない場合は伏せて実行できる。

```bash
aws sts get-caller-identity --output json | sed -E 's/[0-9]{12}/<ACCOUNT_ID>/g'
```

```json
{
    "UserId": "AIDA...",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/admin"
}
```

これでも**「ルートではなくIAMユーザーとして認証されているか」は `Arn` の末尾で確認できる**ため、確認の目的は達せられる。意図したアカウントかどうかだけは、末尾数桁を突き合わせるなどして人間が判断する。

---

## 7. 疎通確認

### 7.1 自分が誰として認証されているかを確認する

```bash
aws sts get-caller-identity
```

```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/admin-user"
}
```

このコマンドは**何も作らず、何も変更しない**。認証が通っているかを確かめるためだけの、最も安全な最初の一歩である。

| フィールド | 読み方 |
| --- | --- |
| `Account` | 12桁のAWSアカウントID。**意図したアカウントか必ず確認する** |
| `Arn` | 自分が「誰として」認証されているか。`user/xxx` ならIAMユーザー、`assumed-role/xxx` ならロールを引き受けた状態 |

`Arn` の末尾が `root` になっていたら、ルートユーザーのアクセスキーを使ってしまっている。[1章](./01-account-setup.md#1-ルートユーザーとiamユーザーの関係)の方針に反するので、そのキーは削除してIAMユーザーのキーを使うこと。

### 7.2 リージョンの確認

```bash
aws configure get region
# ap-northeast-1
```

---

## 8. つまずきやすいエラーと対処

| エラーメッセージ | 原因 | 対処 |
| --- | --- | --- |
| `Unable to locate credentials` | 認証情報が見つからない | `aws configure` を実行したか、`AWS_PROFILE` が存在しないプロファイルを指していないかを確認 |
| `You must specify a region` | 既定リージョンが未設定 | `aws configure set region ap-northeast-1`、または `--region` を都度指定 |
| `The security token included in the request is invalid` | アクセスキーが無効化・削除されている、またはタイプミス | IAMでキーの状態を確認。必要なら再発行（[3.4](./01-account-setup.md#34-漏らしてしまったときの手順)） |
| `Signature expired` / `SignatureDoesNotMatch` | 端末の時刻がずれている | AWSの署名は時刻に依存する。WSL2はスリープ復帰後に時刻がずれることがあるので `sudo hwclock -s` などで同期する |
| `AccessDenied` | 認証は通っているが権限がない | `aws sts get-caller-identity` で「誰として」実行しているかを確認する。認証（誰か）と認可（何をしてよいか）は別の話 |
| リソースが「見つからない」 | リージョンの取り違え | [4.3](./01-account-setup.md#43-リソースはリージョンごとに独立している)を参照 |

---

[← AWS学習ドキュメントトップへ戻る](./README.md)
