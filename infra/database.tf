# データベース（RDS for PostgreSQL）。
#
# バックアップやスナップショットを一切残さない設定にしている。
# これは本番運用では絶対にやってはいけない設定だが、今回は
#   ・データは db/seed/dummy-data.sql からいつでも再投入できる
#   ・destroy後に課金が残る要因を1つも作らない
# という2点を優先した意図的な判断である。
resource "aws_db_instance" "app" {
  identifier = "${var.project}-db"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage = 20 # 12ヶ月無料枠の上限ちょうど
  storage_type      = "gp3"
  storage_encrypted = true # 追加費用はかからない

  # ストレージの自動拡張を無効化する。
  # 有効にしていると、気づかないうちに容量が増えて課金額も増える。
  max_allocated_storage = 0

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # インターネットから直接接続できないようにする。
  # ただしこれはセキュリティグループの代わりではなく、
  # 「パブリックIPを持たせるかどうか」の設定である。両方が必要。
  publicly_accessible = false

  # 待機系を別AZに持つ構成。可用性は上がるが料金がほぼ倍になる。
  multi_az = false

  # EC2と同じAZに置く。
  # 別AZになると、EC2とRDSの間の通信がAZ間データ転送の課金対象になる
  # （往復で $0.01/GB × 2）。同一AZなら無料である。
  availability_zone = aws_subnet.private[0].availability_zone

  # --- ここから下はコスト最小化とdestroyの確実性のための設定 ---

  # 自動バックアップを無効化する（0日保持）。
  # 有効だとスナップショットの保管料が発生し、destroy後も残ることがある。
  backup_retention_period  = 0
  delete_automated_backups = true

  # destroy時に「最終スナップショット」を作らせない。
  # 作ると、DBを消したのにスナップショットの課金だけが延々と残る。
  # 消し忘れ課金の最大の要因がこれである。
  skip_final_snapshot = true

  # trueだと terraform destroy がエラーで失敗する。
  # 数日で消す前提なので明示的にfalseにしておく。
  deletion_protection = false

  # 監視系はいずれも課金対象になりうるので無効にする
  performance_insights_enabled = false
  monitoring_interval          = 0

  # 変更をメンテナンスウィンドウまで待たずに即座に適用する
  apply_immediately = true

  tags = { Name = "${var.project}-db" }
}
