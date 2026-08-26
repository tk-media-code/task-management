# AWS Budgets による予算アラート。
#
# 前提として、Budgetsは「通知するだけで課金を止めない」。
# 詳細は docs/aws/03-cost-management.md 10章。
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # ここが最も重要な設定である。
  # 既定では「クレジットを適用した後の金額」で判定するため、アカウントに
  # 無料クレジットが残っている間はいくら使っても $0 とみなされ、
  # アラートが一度も鳴らないまま クレジットだけが溶けていく。
  # include_credit = false にすると「クレジットが無かったらいくらか」で監視できる。
  cost_types {
    include_credit = false
    include_refund = false
  }

  # 実績80%：すでに使ってしまった分に対する警告。
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  # 予測100%：「このペースだと月末に超える」という予測に対する警告。
  # 実績が出てから気づくより早く動けるため、2本立てにしている。
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
