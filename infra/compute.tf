# アプリケーションサーバー（EC2）。
#
# この1台の中で、ホストのnginxと、バックエンドのDockerコンテナ1つが動く。
# フロントエンドはビルド済みの静的ファイルを置くだけなのでコンテナ化していない。

# 最新のAmazon Linux 2023のAMI IDを取得する。
# AMI IDはリージョンごとに異なるうえ、AWSが更新するたびに変わるため、
# コードに直接書かず、その都度問い合わせる。
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # "al2023-ami-2023.*-x86_64" は標準版にマッチする。
    # minimal版は "al2023-ami-minimal-*" という別の名前なので、この条件では拾わない。
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = file("${path.module}/files/user-data.sh")

  # user_dataは既定では「変更してもインスタンスを作り直さず、再実行もしない」。
  # つまりスクリプトを直しても黙って無視される、という最も分かりにくい挙動になる。
  # trueにすると、変更が plan に -/+（作り直し）として必ず現れるようになる。
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true

    # 既定でtrueだが明示する。falseだとインスタンスを消しても
    # ボリュームだけが残り、課金され続ける（消し忘れの代表例）。
    delete_on_termination = true
  }

  metadata_options {
    # IMDSv2を必須にする。インスタンスメタデータ（IAM認証情報などを含む）の
    # 取得にトークンを要求する方式で、SSRF経由での窃取を防ぐ。
    http_tokens = "required"

    # ホップ数1は「コンテナの中からはメタデータに到達できない」ことを意味する。
    # 今回コンテナはAWSのAPIを叩かないため、絞っておいて差し支えない。
    http_put_response_hop_limit = 1
  }

  credit_specification {
    # T系インスタンスは既定で unlimited モードになっており、
    # CPUクレジットを使い切った後も性能を維持する代わりに追加課金が発生する。
    # standard にすると追加課金は起きず、単に遅くなるだけになる。
    # 予期しない請求を避けたい学習用途では standard が適している。
    cpu_credits = "standard"
  }

  lifecycle {
    # data.aws_ami が「最新」を引く仕組みのため、AWSが新しいAMIを公開するたびに
    # 差分が出て「インスタンスを作り直す」planになってしまう。
    # 一度立てたら作り直したくないので、AMIの変更は無視する。
    ignore_changes = [ami]
  }

  tags = { Name = "${var.project}-app" }
}

# Elastic IPは意図的に作っていない。
# パブリックIPはサブネットの map_public_ip_on_launch により自動で割り当たる。
# EIPは「どこにも紐づいていない状態でも課金される」代表的な消し忘れリソースであり、
# 停止・起動を行わない今回の運用ではIPが変わることもないため、必要がない。
