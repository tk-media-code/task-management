# 予算アラート専用の構成。
#
# アプリ本体（infra/）とstateを分けている理由は、予算アラートが
# 「アプリを消しても残っていてほしい唯一のリソース」だからである。
# 同じstateに置くと terraform destroy で一緒に消え、
# 「消し忘れに気づくための仕組み」そのものが消えてしまう。
#
# これは環境ごとの分割（dev/prod など）ではなくライフサイクルによる分割なので、
# docs/terraform/04-project-conventions.md 13.2 が戒める「凝った構成」には当たらない。

terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # backendブロックを書かない＝ローカルstate（infra/account/terraform.tfstate）。
  # 詳細は docs/terraform/03-state.md 11章。
}

provider "aws" {
  region = var.aws_region

  # 認証情報はここに書かない。AWS CLIと同じ解決順（環境変数 → ~/.aws/credentials）
  # に任せる。詳細は docs/terraform/02-install-and-workflow.md 7章。

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
