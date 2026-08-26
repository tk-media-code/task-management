#!/bin/bash
#
# ローカルでビルドした成果物をEC2へ配置するスクリプト。
#
# なぜローカルでビルドするか:
#   EC2はt3.micro（メモリ1GB）で、GradleもViteもビルドに1GB前後を要求するため、
#   サーバー上ではビルドできない。したがって「ローカルでビルドして成果物だけ送る」
#   という形にしている。これはDockerを使うかどうかとは無関係な、マシンの制約である。
#
# 接続情報を terraform output から取るのはなぜか:
#   IPアドレス・RDSのエンドポイント・パスワードを人が手で打ち写すと、
#   接続できない原因の大半がその打ち間違いになる。読み取り元を1つに固定して、
#   打ち写す工程そのものをなくしている。
#
# terraform apply をこのスクリプトに含めない理由:
#   applyの前に plan の内容を人が読む、という工程を飛ばさないため。
#   詳細は docs/terraform/04-project-conventions.md 16章。
#
# 終了コードの意味:
#   0: 成功
#   1: デプロイに失敗した
#   3: そもそも実行できない（インフラ未構築・コンテナ未起動など環境側の問題）
#
# 使い方:
#   bash scripts/deploy.sh --all       # web → backend の順に配置する
#   bash scripts/deploy.sh --web       # 画面とnginx設定だけ
#   bash scripts/deploy.sh --backend   # APIコンテナだけ
#   bash scripts/deploy.sh --seed      # ダミーデータを投入する（既存データは消える）

set -uo pipefail

# --- 0. 設定 ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra"

readonly FRONTEND_CONTAINER="task-management-frontend"
readonly REMOTE_CONTAINER="task-management-backend"
readonly SSH_KEY="${SSH_KEY:-$HOME/.ssh/task-management-ec2}"

readonly EXIT_OK=0
readonly EXIT_FAILURE=1
readonly EXIT_ENV_ERROR=3

# --- 1. ユーティリティ ---

info()  { echo "[$(date +%H:%M:%S)] $*"; }
fail()  { echo "[エラー] $*" >&2; }

# terraform output から1つの値を取り出す。
# インフラが未構築ならここで失敗するので、以降の処理に進まない。
tf_output() {
	terraform -chdir="$INFRA_DIR" output -raw "$1" 2>/dev/null
}

# 実行前の環境確認。コードではなく環境側の問題を、実行前にまとめて検出する。
preflight() {
	if ! command -v terraform >/dev/null 2>&1; then
		fail "terraform コマンドが見つかりません。"
		return 1
	fi

	if [ ! -f "$INFRA_DIR/terraform.tfstate" ]; then
		fail "infra/terraform.tfstate がありません。先にインフラを構築してください。"
		echo "  terraform -chdir=infra apply" >&2
		return 1
	fi

	if [ ! -f "$SSH_KEY" ]; then
		fail "SSHの秘密鍵が見つかりません: $SSH_KEY"
		echo "  ssh-keygen -t ed25519 -f ~/.ssh/task-management-ec2 -N '' で作成してください。" >&2
		return 1
	fi

	HOST="$(tf_output ec2_public_ip)"
	if [ -z "$HOST" ]; then
		fail "EC2のIPアドレスを取得できません。インフラが構築済みか確認してください。"
		return 1
	fi

	# StrictHostKeyChecking=accept-new を使う理由:
	# applyのたびにIPもホスト鍵も変わりうるため、未知のホストは自動で受け入れる。
	# 既知のIPで鍵だけが変わった場合は警告が出るので、そのときは
	# ssh-keygen -R <IP> で古い記録を消す。
	SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

	if ! ssh "${SSH_OPTS[@]}" "ec2-user@$HOST" 'true' 2>/dev/null; then
		fail "EC2に接続できません: ec2-user@$HOST"
		echo "  セキュリティグループのSSH許可元が現在のIPと一致しているか確認してください。" >&2
		echo "  現在のIP: $(curl -s https://checkip.amazonaws.com 2>/dev/null)" >&2
		return 1
	fi

	return 0
}

# リモートでコマンドを実行する。
remote() {
	ssh "${SSH_OPTS[@]}" "ec2-user@$HOST" "$@"
}

# --- 2. フロントエンドとnginx設定の配置 ---

deploy_web() {
	info "フロントエンドをビルドします"

	# ホストのnpmではなくコンテナ内でビルドする。
	# frontend/dist/ はコンテナ（root）が作ったディレクトリのため、
	# ホスト側のユーザーからは書き込めずPermission deniedになる。
	# ビルド環境をCI・品質チェックと揃えられるという利点もある。
	if ! docker exec -w /workspace "$FRONTEND_CONTAINER" npm run build; then
		fail "フロントエンドのビルドに失敗しました。"
		return 1
	fi

	info "nginx設定と静的ファイルを転送します"

	scp "${SSH_OPTS[@]}" "$INFRA_DIR/files/nginx.conf" "ec2-user@$HOST:/tmp/nginx.conf" || return 1

	# --delete を付ける理由: Viteはファイル名にハッシュを含めるため、
	# 付けないと過去のビルドの資産が消えずに溜まり続ける。
	rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
		"$REPO_ROOT/frontend/dist/" "ec2-user@$HOST:/home/ec2-user/dist/" || return 1

	info "EC2側に配置してnginxを再読み込みします"

	remote 'set -eu
		sudo install -m 644 -o root -g root /tmp/nginx.conf /etc/nginx/nginx.conf
		rm -f /tmp/nginx.conf
		sudo rsync -a --delete /home/ec2-user/dist/ /var/www/dist/
		# nginxのワーカーは nginx ユーザーで動くため、読める権限にしておく
		sudo chown -R root:root /var/www/dist
		sudo chmod -R a+rX /var/www/dist
		# 必ず構文チェックを通してから反映する。
		# 設定ミスのまま restart すると nginx が停止し、自動では復旧しない。
		# reload なら、検証に通った設定だけが無停止で反映される。
		sudo nginx -t
		sudo systemctl reload nginx' || return 1

	return 0
}

# --- 3. バックエンドコンテナの配置 ---

deploy_backend() {
	# タグにgitのショートSHAを使う。
	# latest固定だと「転送したつもりが古いイメージのまま」という状態に気づけない。
	local tag image
	tag="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
	image="$REMOTE_CONTAINER:$tag"

	info "バックエンドのイメージをビルドします ($image)"

	# --platform を明示する。ローカルもEC2もx86_64だが、別のマシンでビルドしたときに
	# アーキテクチャ不一致のイメージが黙って出来上がるのを防ぐ。
	if ! docker build --platform linux/amd64 -t "$image" "$REPO_ROOT/backend"; then
		fail "バックエンドのビルドに失敗しました。"
		return 1
	fi

	info "イメージを転送します（圧縮後およそ170MB。1分ほどかかります）"

	# docker load は gzip を自動的に判別して展開する。
	if ! docker save "$image" | gzip -1 | remote 'docker load'; then
		fail "イメージの転送に失敗しました。"
		return 1
	fi

	info "接続情報を配置します"

	# umask 077 でファイルを600にしてから書き出す。
	# SPRING_PROFILES_ACTIVE は意図的に書かない。devプロファイルを渡すと
	# CORS許可・SQLログ（バインド値を含む）・ヘルスチェックの詳細表示が
	# 有効になってしまうため、本番では application.properties の既定値を使う。
	#
	# PG* 変数も併記しているのは、EC2上で psql を叩くときに
	# ホスト名やパスワードを打ち込まずに済むようにするため。
	printf 'DB_URL=%s\nDB_USERNAME=%s\nDB_PASSWORD=%s\nPGHOST=%s\nPGPORT=5432\nPGDATABASE=%s\nPGUSER=%s\nPGPASSWORD=%s\n' \
		"$(tf_output backend_db_url)" \
		"$(tf_output db_username)" \
		"$(tf_output db_password)" \
		"$(tf_output db_host)" \
		"$(tf_output db_name)" \
		"$(tf_output db_username)" \
		"$(tf_output db_password)" \
		| remote 'umask 077 && cat > /home/ec2-user/app.env' || return 1

	info "コンテナを起動します"

	# -p 127.0.0.1:8080:8080 とループバックに限定している。
	# セキュリティグループが8080を塞いでいるので現時点でも外からは届かないが、
	# 「認証や公開の判断はnginxだけが持つ」という状態を、SGの設定内容に
	# 依存せず成立させておく。
	#
	# --restart unless-stopped は、EC2の再起動後もコンテナを復帰させる。
	# always と違い、自分で明示的に止めたコンテナは勝手に起き上がらない。
	remote "set -eu
		docker rm -f $REMOTE_CONTAINER 2>/dev/null || true
		docker run -d --name $REMOTE_CONTAINER \
			--restart unless-stopped \
			-p 127.0.0.1:8080:8080 \
			--env-file /home/ec2-user/app.env \
			-e TZ=Asia/Tokyo \
			$image
		# 古いタグのイメージを掃除する。16GBのディスクを食い潰さないため
		docker image prune -f >/dev/null" || return 1

	info "アプリケーションの起動を待ちます（Spring Bootの起動に20〜30秒かかります）"

	# ヘルスチェックが通るまで待つ。
	# ここで待たずに終了すると、直後の動作確認が502になって
	# 「デプロイに失敗した」と誤解する原因になる。
	local i
	for i in $(seq 1 30); do
		if remote 'curl -sf http://127.0.0.1:8080/actuator/health >/dev/null 2>&1'; then
			info "アプリケーションが応答しました"
			return 0
		fi
		sleep 3
	done

	fail "アプリケーションが起動しませんでした。ログを確認してください:"
	echo "  ssh -i $SSH_KEY ec2-user@$HOST 'docker logs --tail 50 $REMOTE_CONTAINER'" >&2
	return 1
}

# --- 4. ダミーデータの投入 ---

deploy_seed() {
	# このSQLは冒頭で TRUNCATE を実行するため、既存のデータはすべて消える。
	# --all に含めていないのはそのためで、明示的に指定したときだけ実行する。
	#
	# 前提として、backendを一度起動して ddl-auto=update にテーブルを
	# 作らせておく必要がある。テーブルが無い状態で流すと
	# relation "board" does not exist で失敗する。
	#
	# PGTZ=Asia/Tokyo を指定する理由:
	# SQL内の期日は CURRENT_DATE を基準にした相対値で書かれている。
	# RDSの既定タイムゾーンはUTCなので、日本時間の朝9時より前に実行すると
	# 日付が1日ずれ、画面上で余計に「期限切れ」が増える。
	info "ダミーデータを投入します（既存のデータは削除されます）"

	remote 'set -a; . /home/ec2-user/app.env; set +a
		PGTZ=Asia/Tokyo psql -v ON_ERROR_STOP=1' < "$REPO_ROOT/db/seed/dummy-data.sql" || return 1

	return 0
}

# --- 5. 引数の解釈と実行 ---

usage() {
	sed -n '/^# 使い方:/,/--seed/p' "$0" | sed 's/^# \{0,1\}//'
}

main() {
	local do_web=0 do_backend=0 do_seed=0

	if [ $# -eq 0 ]; then
		usage
		return $EXIT_ENV_ERROR
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			--all)     do_web=1; do_backend=1 ;;
			--web)     do_web=1 ;;
			--backend) do_backend=1 ;;
			--seed)    do_seed=1 ;;
			-h|--help) usage; return $EXIT_OK ;;
			*)         fail "不明な引数: $1"; usage; return $EXIT_ENV_ERROR ;;
		esac
		shift
	done

	if ! preflight; then
		return $EXIT_ENV_ERROR
	fi

	info "デプロイ先: $HOST"

	if [ "$do_web" -eq 1 ] && ! deploy_web; then
		return $EXIT_FAILURE
	fi

	if [ "$do_backend" -eq 1 ] && ! deploy_backend; then
		return $EXIT_FAILURE
	fi

	if [ "$do_seed" -eq 1 ] && ! deploy_seed; then
		return $EXIT_FAILURE
	fi

	echo
	info "完了しました: $(tf_output app_url)"
	return $EXIT_OK
}

main "$@"
