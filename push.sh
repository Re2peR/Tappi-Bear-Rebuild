#!/bin/bash
# push.sh — 初始化并推送到 GitHub
# 用法:
#   GITHUB_TOKEN=ghp_xxx ./push.sh
#
# 本机没有 git，脚本会用 E:\AI\Tappi Bear\git-portable 里的便携版。

set -e

GIT="/e/AI/Tappi Bear/git-portable/cmd/git.exe"
REPO="Re2peR/Tappi-Bear-Rebuild"

if [ -z "$GITHUB_TOKEN" ]; then
  echo "ERROR: 需要设置 GITHUB_TOKEN"
  echo "  export GITHUB_TOKEN=ghp_xxxxxxxx"
  exit 1
fi

cd "$(dirname "$0")"

"$GIT" init -b main 2>/dev/null || "$GIT" init
"$GIT" config user.name "Re2peR"
"$GIT" config user.email "29789048+Re2peR@users.noreply.github.com"
"$GIT" config core.autocrlf false
"$GIT" config core.fileMode false

"$GIT" add -A
"$GIT" -c core.pager=cat status --short | head -n 20
echo "..."
"$GIT" -c core.pager=cat status --short | wc -l

"$GIT" commit -m "P0: arm64 skeleton, cocos2d-objc 3.5 compat layer, animation data, CI"

# 用 token 推送（不落盘到 remote url）
"$GIT" push "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" main --force

echo "pushed."
