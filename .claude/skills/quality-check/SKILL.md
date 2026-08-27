---
name: quality-check
description: push前の品質チェック（backend の Checkstyle/SpotBugs/テスト、frontend の oxlint/型チェック/ビルド）をまとめて実行する時に使用。「品質チェックして」「lint かけて」「push していい？」「pushする前に確認して」と言われたら発動。git push を実行する前には、指示が無くても必ずこの手順で確認する。結果を報告するだけで、commit / push / PR 作成は行わない。
argument-hint: "[backend|frontend]"
---

# Quality Check Skill — push前の品質チェック

## 目的

`.github/workflows/ci.yml` はビルド（コンパイル・パッケージング・型チェック）が通ることしか見ない。Checkstyle・SpotBugs・oxlintといった静的解析や、backendの既存テストは、**push前のこの手順が唯一の検出機会**になる。

`git push` を含むコマンドはガードフック（Claude Code は `.claude/hooks/guard.cjs`、Cursor は `.cursor/hooks/guard.cjs`。判定は共通の `guard-core.cjs`）が検知し、`scripts/harness-check.sh`（共通チェック）→ このスキルと同じ `scripts/quality-check.sh` の順で自動実行して、失敗時にはpush自体をブロックする。フックに引っかかってから修正するより、push前に自発的にこのスキルを使ってクリーンな状態でpushする方が、往復が1回少なくて済む。フックは最後の砦、このスキルが通常運転という役割分担になる。

## 実行手順

### 1. 対象を決める
- 引数（`--backend` / `--frontend`）があればそれに従う。frontendしか触っていない場合は `--frontend` で時短してよい。
- **push の直前は必ず引数なし（全体）で実行する。**

### 2. スクリプトを実行する
このスキルが置かれているリポジトリ（task-management）のルートで実行する。

```bash
# backend・frontend両方
bash scripts/quality-check.sh

# 片方だけ
bash scripts/quality-check.sh --backend
bash scripts/quality-check.sh --frontend
```

### 3. 結果を報告する

終了コードで次に取るべき行動が変わる。

| 終了コード | 意味 | 取るべき行動 |
| --- | --- | --- |
| 0 | 全チェック合格 | pushしてよい |
| 1 | 品質上の問題を検出 | 出力に含まれる指摘（Checkstyleの`file:line`、SpotBugsの指摘、oxlintの指摘、`tsc`/`vite build`のエラー等）を確認し、**修正 → コミット → 再度このスキルを実行、を指摘が解消するまで繰り返す**。ユーザーに確認を求めてよいのは、修正方針に複数の選択肢があり判断に迷う場合、または影響範囲が大きい修正が必要な場合に限る |
| 3 | 環境の問題でチェックを実行できない | 出力の案内に従う（`docker compose up -d` でコンテナ起動、またはgit worktree外＝メインチェックアウトへ移動） |

## 仕様メモ

- **このスキルは commit / push / PR 作成を自動では行わない。** チェックして結果を報告するところで止まり、pushするかどうかはユーザー・呼び出し元の判断に委ねる（`.claude/skills/prompt-log/SKILL.md` と同じガード方針）。
- 指摘が残ったままどうしても push する必要がある場合は、**ユーザーが明示的に許可したときだけ** `SKIP_QUALITY_CHECK=1 git push ...` を使う。Claude が自己判断でこの変数を付けることは `CLAUDE.md` で禁止されている。
- **git worktree（`.claude/worktrees/`配下）で作業している場合、終了コード3で止まる。** backend/frontendのDockerコンテナはメインチェックアウトを `/workspace` にマウントしており、worktree内から`docker exec`すると別のコードを検査してしまうため、意図的にブロックしている（`scripts/quality-check.sh`のworktreeガード）。メインチェックアウトで作業すること。
- SpotBugsのレポートはコンテナ内の名前付きボリューム（`/workspace/build`）にあり、ホストの`backend/build/`からは見えない。失敗時、`scripts/quality-check.sh`が`docker exec ... cat build/reports/spotbugs/main.txt`で中身を出力に含めるため、追加の確認作業は不要。
- backendの`gradlew check`は増分ビルドを使うため、`compileJava`がUP-TO-DATEだと`-Xlint:all`の警告は再表示されない（既知の仕様。ソースを変更していないのに警告が消えて見えても異常ではない）。
- `frontend (oxlint)` は現時点で `--deny-warnings` を付けていない。既知のwarning 8件（Issue #66・#67で対応予定）が解消するまでの暫定措置で、`scripts/quality-check.sh`冒頭の`OXLINT_ARGS`を変更すれば有効化できる。
