# ---------------------------------------------------------------------------
# 基本
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "リソースを作成するリージョン"
  type        = string
  default     = "ap-northeast-1"
  # リージョンだけはコードに固定する。認証情報と違い秘密ではなく、
  # 環境変数まかせにすると「意図しないリージョンに作ってしまい、
  # コンソールで探しても見つからない」という事故が起きるため。
}

variable "project" {
  description = "リソース名とタグに使う接頭辞"
  type        = string
  default     = "task-management"
}

# ---------------------------------------------------------------------------
# ネットワーク
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

# ---------------------------------------------------------------------------
# アクセス制御
# ---------------------------------------------------------------------------

variable "ssh_allowed_cidr" {
  description = "SSH(22)を許可する送信元CIDR。自分のグローバルIPを /32 で指定する"
  type        = string

  validation {
    # SSHの全開放は事故に直結するため、コード側で機械的に止める。
    # 「気をつける」という人間の注意力に頼らないのが要点。
    condition     = var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "SSHを 0.0.0.0/0 に開けることはできません。curl -s https://checkip.amazonaws.com で自分のIPを確認し、/32 を付けて指定してください。"
  }
}

variable "http_allowed_cidrs" {
  description = "HTTP(80)を許可する送信元CIDRのリスト"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  # 今回はベーシック認証もHTTPSも実装しない判断をしたため、
  # 80番を開けた時点で「URLを知る者は誰でも操作できる」状態になる。
  # 人に見せる必要がない間は ["<自分のIP>/32"] に絞れるよう変数にしてある。
}

variable "ssh_public_key_path" {
  description = "EC2に登録する公開鍵のパス。秘密鍵はローカルに置いたままにする"
  type        = string
  default     = "~/.ssh/task-management-ec2.pub"
}

# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2のインスタンスタイプ"
  type        = string
  default     = "t3.micro"
  # x86_64系を選ぶ。ローカル（WSL2 / x86_64）でビルドしたDockerイメージを
  # そのまま動かすため、アーキテクチャを揃える必要があるからである。
  # ARM系のGraviton（t4g）は2割ほど安いが、イメージが動かない。
}

variable "root_volume_size" {
  description = "EC2のルートボリュームのサイズ（GB）"
  type        = number
  default     = 16
  # 既定の8GBだと、Dockerイメージを数世代置いた時点で逼迫する。
  # 12ヶ月無料枠は30GBまでなので、16GBなら枠内に収まる。
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "db_instance_class" {
  description = "RDSのインスタンスクラス"
  type        = string
  default     = "db.t4g.micro"
  # EC2と違い、RDSはAWS側が中で動かすマネージドサービスなので、
  # こちらのDockerイメージのアーキテクチャとは無関係である。
  # したがって2割ほど安いGraviton（t4g）を選んでよい。
}

variable "db_engine_version" {
  description = "PostgreSQLのバージョン"
  type        = string
  default     = "18"
  # メジャーバージョンだけを指定する。マイナーまで固定すると、
  # AWSがそのマイナーを廃止したときにapplyが通らなくなるため。
  # ローカル開発は postgres:18 なのでメジャーは揃っている。
}

variable "db_name" {
  description = "作成するデータベース名"
  type        = string
  default     = "taskmanagement"
}

variable "db_username" {
  description = "RDSのマスターユーザー名"
  type        = string
  default     = "taskuser"
  # postgres や admin などの予約語は使えない。
}

variable "db_password" {
  description = "RDSのマスターパスワード。英数字のみにすること"
  type        = string
  sensitive   = true
  # sensitive = true は plan/apply の画面表示で値を伏せるだけの機能で、
  # stateには平文で書き込まれる。「付けたから安全」ではない。
  # 詳細は docs/terraform/04-project-conventions.md 15.3。

  validation {
    # 記号を禁じている理由は3つ重なっている。
    #   1. RDSがマスターパスワードに / @ " と空白を許可していない
    #   2. 同じ値を書いた app.env を docker の --env-file が読むが、
    #      これはクォートを値の一部として扱う
    #   3. 同じファイルをシェルの . (source) でも読むが、
    #      こちらはクォートを外して解釈する（2と正反対）
    # 英数字だけに制限すれば、3者すべてで同じ値として扱われる。
    condition     = can(regex("^[A-Za-z0-9]{16,41}$", var.db_password))
    error_message = "db_password は英数字（記号なし）16〜41文字にしてください。openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24 で生成できます。"
  }
}
