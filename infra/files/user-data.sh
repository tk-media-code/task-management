#!/bin/bash
#
# EC2の初回起動時に cloud-init が root 権限で一度だけ実行するスクリプト。
#
# ここで行うのは「OSに何を入れるか」までに限定している。
# nginxの設定ファイルやアプリ本体（dist/・Dockerイメージ）は
# scripts/deploy.sh が scp で配る。
#
# 理由は、user_dataが「一度しか実行されない」性質を持つためである。
# 内容を変更してもインスタンス内で再実行されることはなく、
# Terraform側で user_data_replace_on_change = true を指定しているため
# 変更＝インスタンスの作り直し（IPも変わる）になる。
# nginxの設定は試行錯誤で何度も直すものなので、ここに含めると苦痛になる。
#
# 実行ログは /var/log/cloud-init-output.log に残る。
# 起動後に何かがおかしいときは、まずこのファイルを見ること。

set -euxo pipefail

dnf update -y

# nginx : 静的ファイルの配信と /api/* のリバースプロキシを担う
# docker: バックエンドを1コンテナとして動かす
# rsync : dist/ の差分転送に使う（Amazon Linux 2023 には既定で入っていない）
dnf install -y nginx docker rsync

# psqlクライアント。
# コンテナを起動する前に「EC2からRDSに届くか」だけを切り分けるために使う。
# ここを先に確定させておかないと、アプリが起動しないときに
# 「ネットワークの問題」「認証情報の問題」「コンテナの問題」が混ざって切り分けできない。
# seedデータの流し込みにも使う。
# Amazon Linux 2023 はリリースによって提供メジャーが違うため、新しい順に試す。
dnf install -y postgresql17 || dnf install -y postgresql16 || dnf install -y postgresql15

# 静的ファイルの置き場。
# nginxのワーカープロセスは nginx ユーザーで動くため、そのユーザーが辿れる場所に置く。
# ec2-userのホームディレクトリ配下（既定で700）に置くと、nginxが読めず403になる。
install -d -m 755 /var/www/dist

# 2GBのスワップ領域。
# t3.microはメモリが1GBしかなく、OS・docker・nginx・JVM（Spring Boot）を
# 同時に載せると余裕が小さい。EBS上のスワップは遅いが、
# メモリ不足でOOM Killerにコンテナを落とされるよりはましである。
# EBSの無料枠は30GBなので、この2GBは追加費用にならない。
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  # 再起動後も有効にする
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --now を付けると「自動起動の有効化」と「今すぐ起動」を同時に行う
systemctl enable --now docker
systemctl enable --now nginx

# ec2-user が sudo なしで docker を使えるようにする。
# グループの変更は「新しいログインセッション」からしか反映されないため、
# このスクリプトと同じセッション内では反映されない。
# deploy.sh は毎回sshで接続し直すので問題にならない。
usermod -aG docker ec2-user
