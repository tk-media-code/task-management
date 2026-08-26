# 出力値。
#
# scripts/deploy.sh がこれらを terraform output -raw で読み取ることで、
# IPアドレスやパスワードを人間が手で打ち写す工程をなくしている。
# 接続できないときの原因は、たいてい単純な打ち間違いだからである。

output "app_url" {
  description = "アプリケーションのURL"
  value       = "http://${aws_instance.app.public_ip}/"
}

output "ec2_public_ip" {
  description = "EC2のパブリックIP"
  value       = aws_instance.app.public_ip
}

output "ssh_command" {
  description = "EC2に接続するコマンド"
  value       = "ssh -i ~/.ssh/task-management-ec2 ec2-user@${aws_instance.app.public_ip}"
}

output "db_host" {
  description = "RDSのホスト名（ポートを含まない）"
  value       = aws_db_instance.app.address
}

output "db_name" {
  description = "データベース名"
  value       = aws_db_instance.app.db_name
}

output "db_username" {
  description = "DBのユーザー名"
  value       = aws_db_instance.app.username
}

output "backend_db_url" {
  description = "バックエンドに渡すJDBCのURL"
  # endpoint は "ホスト名:ポート" の形式で返るため、そのままURLに組み込める
  value = "jdbc:postgresql://${aws_db_instance.app.endpoint}/${aws_db_instance.app.db_name}"
}

output "db_password" {
  description = "DBのパスワード（terraform output -raw db_password で取得）"
  value       = var.db_password
  sensitive   = true
  # この値はもともとstateに平文で保存されているため、
  # outputにしたことで新たに漏れる経路が増えるわけではない。
  # むしろ手で打ち写す経路をなくせる分、事故が減る。
}
