variable "aws_region" {
  description = "リソースを作成するリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "リソース名とタグに使う接頭辞"
  type        = string
  default     = "task-management"
}

variable "budget_limit_usd" {
  description = "月あたりの予算額（USD）。この額に対する割合でアラートが鳴る"
  type        = string
  default     = "10"
  # 5日程度の稼働で実費は $6 前後の見込み。$10 にしておくと
  # 「無料枠が効かなかった」「destroyし忘れた」のどちらでも早期に気づける。
}

variable "budget_notification_email" {
  description = "予算アラートの通知先メールアドレス"
  type        = string
  # 既定値は置かない。通知先は環境ごとに違ううえ、
  # 間違ったアドレスに送っても「鳴らない」ことに気づけないため、明示的に指定させる。
}
