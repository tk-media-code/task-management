# タスク管理アプリの本番環境（EC2 1台 + RDS）。
#
# 構成の意図と、採用しなかった選択肢については docs/aws/05-deploy-architecture.md を参照。
# 公開後数日で terraform destroy する前提のため、コストを最優先で削っている。

terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # backendブロックを書かない＝ローカルstate（infra/terraform.tfstate）。
  # S3バックエンドは複数人・複数端末で共有する場合に効く仕組みで、
  # 単独作業かつ数日で消す今回の構成には過剰なため使わない。
  # 詳細は docs/terraform/03-state.md 11章。
}

provider "aws" {
  region = var.aws_region

  # 認証情報はここに書かない。AWS CLIと同じ解決順に任せる。
  # 詳細は docs/terraform/02-install-and-workflow.md 7章。

  # ここで指定したタグが、このプロバイダで作る全リソースに自動で付く。
  # リソースごとに tags を書く方式だと必ず付け忘れが出るが、この方式なら漏れない。
  # destroy後に「消し忘れたリソースが無いか」を探すとき、
  # このタグ1つで全リソースを串刺しに検索できるのが最大の利点である。
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
