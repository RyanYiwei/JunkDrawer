#!/bin/bash

# Usage: ./setup-sync.sh user@server:/path/to/remote /path/to/local

set -e

REMOTE="$1"
LOCAL="$2"

if [ -z "$REMOTE" ] || [ -z "$LOCAL" ]; then
  echo "Usage: $0 user@server:/path/to/remote /path/to/local"
  exit 1
fi

mkdir -p "$LOCAL"

# 先检查服务器上有没有 .gitignore
REMOTE_HOST="${REMOTE%%:*}"
REMOTE_PATH="${REMOTE#*:}"

echo "检查服务器上是否有 .gitignore..."

EXCLUDES=(
  --exclude 'push.sh'
  --exclude 'pull.sh'
)

if ssh "$REMOTE_HOST" "test -f '$REMOTE_PATH/.gitignore'"; then
  echo "发现 .gitignore，下载时排除相关文件..."
  rsync -avz --filter=':- .gitignore' "${EXCLUDES[@]}" "$REMOTE/" "$LOCAL/"
else
  echo "未发现 .gitignore，直接下载..."
  rsync -avz "${EXCLUDES[@]}" "$REMOTE/" "$LOCAL/"
fi

# 生成 push.sh
cat > "$LOCAL/push.sh" << EOF
#!/bin/bash

# 把本地文件推送到服务器
# 忽略 .gitignore 里的内容，以及 push.sh / pull.sh 本身
# 服务器上独有的文件不会被删除

REMOTE="$REMOTE"
LOCAL="\$(cd "\$(dirname "\$0")" && pwd)"

EXCLUDES=(
  --exclude 'push.sh'
  --exclude 'pull.sh'
)

if [ -f "\$LOCAL/.gitignore" ]; then
  rsync -avz --filter=':- .gitignore' "\${EXCLUDES[@]}" "\$LOCAL/" "\$REMOTE/"
else
  rsync -avz "\${EXCLUDES[@]}" "\$LOCAL/" "\$REMOTE/"
fi

echo "✅ 推送完成：\$LOCAL -> \$REMOTE"
EOF

# 生成 pull.sh
cat > "$LOCAL/pull.sh" << EOF
#!/bin/bash

# 从服务器拉取最新文件到本地
# 忽略 .gitignore 里的内容，以及 push.sh / pull.sh 本身
# 本地独有的文件不会被删除

REMOTE="$REMOTE"
LOCAL="\$(cd "\$(dirname "\$0")" && pwd)"

EXCLUDES=(
  --exclude 'push.sh'
  --exclude 'pull.sh'
)

if [ -f "\$LOCAL/.gitignore" ]; then
  rsync -avz --filter=':- .gitignore' "\${EXCLUDES[@]}" "\$REMOTE/" "\$LOCAL/"
else
  rsync -avz "\${EXCLUDES[@]}" "\$REMOTE/" "\$LOCAL/"
fi

echo "✅ 拉取完成：\$REMOTE -> \$LOCAL"
EOF

chmod +x "$LOCAL/push.sh" "$LOCAL/pull.sh"

echo ""
echo "✅ 初始下载完成！本地路径：$LOCAL"
echo ""
echo "以后使用："
echo "   ./push.sh   把本地改动推送到服务器"
echo "   ./pull.sh   把服务器更新拉到本地"