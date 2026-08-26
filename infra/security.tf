# セキュリティグループとキーペア。
#
# セキュリティグループはEC2インスタンスの外側（ENI＝仮想NIC）で評価される、
# ステートフルなファイアウォールである。「ステートフル」とは、
# 許可した通信の戻りパケットが自動で通ることを意味する。
# したがって「HTTPを受ける」ためにegress側で何かを許可する必要はない。
#
# ルールをSGリソースのインライン（ingressブロック）ではなく独立したリソースで
# 書いているのは、planの読みやすさのためである。自宅のIPが変わって
# ssh_allowed_cidr を書き換えたとき、インライン形式だと「SG全体の書き換え」に
# 見えて怖いが、この形式なら「ルール1本の置き換え」として出る。

# ---------------------------------------------------------------------------
# EC2用
# ---------------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project}-ec2"
  description = "EC2: HTTP from internet, SSH from my IP"
  vpc_id      = aws_vpc.main.id

  # ingress/egressブロックはここに書かない。
  # 独立したルールリソースと併用すると、互いの変更を打ち消し合う。

  tags = { Name = "${var.project}-ec2-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  for_each = toset(var.http_allowed_cidrs)

  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "HTTP"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH from my IP only"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # 全プロトコル。-1のときはfrom_port/to_portを書かない

  # descriptionには日本語（マルチバイト文字）を書けない。
  # AWSが許可するのは a-zA-Z0-9 と一部の記号だけで、
  # 違反すると apply 時に InvalidParameterValue で弾かれる。
  # 日本語で書きたい説明は、このようにコメントとして残す。
  # ここでのegressの用途は「dnfでのパッケージ取得」と「RDSへの接続」である。
  description = "outbound for dnf and RDS"
}

# アプリのポート8080に対するingressルールは、意図的に作っていない。
# バックエンドのコンテナは 127.0.0.1:8080 にだけ公開し、
# 同じホスト上のnginxからのみ到達させる設計のためである。

# ---------------------------------------------------------------------------
# RDS用
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds"
  description = "RDS: PostgreSQL from EC2 security group only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id = aws_security_group.rds.id

  # 送信元にCIDRではなくセキュリティグループを指定している。
  # これがAWSらしい書き方で、利点が2つある。
  #   1. EC2のプライベートIPが変わっても追随しなくてよい
  #   2. 「このSGが付いたインスタンスだけ」という意図がコードに現れる
  referenced_security_group_id = aws_security_group.ec2.id

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432
  description = "PostgreSQL from EC2"
}

# RDS側にegressルールは作らない。
# RDSは接続を受けるだけで自分から外に出ることがないため、
# 「無い」のが正しい状態である。これはNAT Gatewayを作らずに済む理由でもある。

# ---------------------------------------------------------------------------
# キーペア
# ---------------------------------------------------------------------------

resource "aws_key_pair" "deployer" {
  key_name = "${var.project}-deployer"

  # pathexpand() が必要である。Terraformの file() は "~" を
  # ホームディレクトリに展開しないため、そのまま渡すとエラーになる。
  public_key = file(pathexpand(var.ssh_public_key_path))

  # AWSに渡すのは公開鍵だけで、秘密鍵はローカルに置いたままにする。
  # tls_private_key リソースでTerraformに鍵を生成させる方法もあるが、
  # その場合「秘密鍵がstateに平文で保存される」ため使わない。
  # 詳細は docs/terraform/03-state.md 12章。

  tags = { Name = "${var.project}-deployer" }
}
