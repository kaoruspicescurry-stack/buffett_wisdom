#!/bin/bash
# YouTube コメント取得ツール (curl版)
# ユーザーのGASコードのロジックをcurl + YouTube Data API v3で再現
#
# 使い方: 
#   YOUTUBE_API_KEY=xxxxx bash fetch_comments.sh <video_id1> [video_id2 ...]
#   または環境変数 YOUTUBE_API_KEY を事前に設定
#
# 出力: Markdown形式で標準出力

API_BASE="https://www.googleapis.com/youtube/v3"
MAX_RESULTS=100

# APIキーチェック
if [ -z "$YOUTUBE_API_KEY" ]; then
  echo "❌ YOUTUBE_API_KEY が設定されていません" >&2
  echo "使い方: YOUTUBE_API_KEY=xxxxx bash $0 <video_id>" >&2
  exit 1
fi

# 引数チェック
if [ $# -eq 0 ]; then
  echo "❌ 動画IDを指定してください" >&2
  echo "使い方: bash $0 <video_id1> [video_id2 ...]" >&2
  exit 1
fi

# 全動画のコメントを取得
for VIDEO_ID in "$@"; do
  echo ""
  echo "---"
  echo ""
  echo "## 動画: ${VIDEO_ID}"
  echo ""

  # 動画情報取得
  VIDEO_INFO=$(curl -s "${API_BASE}/videos?part=snippet,statistics&id=${VIDEO_ID}&fields=items(snippet(title,channelTitle),statistics(viewCount,likeCount,commentCount))&key=${YOUTUBE_API_KEY}")
  
  TITLE=$(echo "$VIDEO_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['items'][0]['snippet']['title'])" 2>/dev/null || echo "不明")
  CHANNEL=$(echo "$VIDEO_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['items'][0]['snippet']['channelTitle'])" 2>/dev/null || echo "不明")
  VIEW_COUNT=$(echo "$VIDEO_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['items'][0]['statistics']['viewCount'])" 2>/dev/null || echo "0")
  COMMENT_COUNT=$(echo "$VIDEO_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['items'][0]['statistics']['commentCount'])" 2>/dev/null || echo "0")

  echo "**タイトル**: ${TITLE}"
  echo "**チャンネル**: ${CHANNEL}"
  echo "**再生回数**: ${VIEW_COUNT} / **コメント数**: ${COMMENT_COUNT}"
  echo "**URL**: https://www.youtube.com/watch?v=${VIDEO_ID}"
  echo ""
  echo "### コメント一覧"
  echo ""

  PAGE_TOKEN=""
  COMMENT_NUM=0

  while true; do
    # コメント取得
    URL="${API_BASE}/commentThreads?part=snippet&videoId=${VIDEO_ID}&maxResults=${MAX_RESULTS}&textFormat=plainText&order=relevance&fields=nextPageToken,items(snippet(topLevelComment(snippet(authorDisplayName,textDisplay,likeCount,publishedAt))))&key=${YOUTUBE_API_KEY}"
    
    if [ -n "$PAGE_TOKEN" ]; then
      URL="${URL}&pageToken=${PAGE_TOKEN}"
    fi

    RESPONSE=$(curl -s "$URL")

    # エラーチェック
    ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
    if [ -n "$ERROR" ] && [ "$ERROR" != "" ]; then
      echo "❌ APIエラー: $ERROR" >&2
      break
    fi

    # コメント解析・出力
    COMMENTS_OUTPUT=$(python3 -c "
import sys, json

data = json.load(sys.stdin)
items = data.get('items', [])
start_num = int(sys.argv[1])

for i, item in enumerate(items):
    snippet = item['snippet']['topLevelComment']['snippet']
    name = snippet.get('authorDisplayName', '')
    text = snippet.get('textDisplay', '').replace('\n', ' ')
    likes = snippet.get('likeCount', 0)
    num = start_num + i + 1
    print(f'{num}. **{name}** (👍 {likes}): {text}')

# 最後に処理した件数を stderr に出力
print(len(items), file=sys.stderr)
" "$COMMENT_NUM" <<< "$RESPONSE" 2>/tmp/comment_count)

    echo "$COMMENTS_OUTPUT"
    
    BATCH_COUNT=$(cat /tmp/comment_count 2>/dev/null || echo "0")
    COMMENT_NUM=$((COMMENT_NUM + BATCH_COUNT))

    # 次のページトークン
    PAGE_TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('nextPageToken',''))" 2>/dev/null)

    if [ -z "$PAGE_TOKEN" ]; then
      break
    fi

    # 2ページまで取得（計200件程度）
    if [ $COMMENT_NUM -ge 200 ]; then
      break
    fi
  done

  echo ""
  echo "**取得コメント数**: ${COMMENT_NUM}件"
  echo ""
done
