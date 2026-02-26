#!/bin/bash


set -eo pipefail

PAGES="$1"
VECTOR_BUCKET="$2"
VECTOR_INDEX="$3"

# JSONの要素数を取得
ELEMENT_COUNT=$(echo "$PAGES" | jq 'length')
echo "要素数: $ELEMENT_COUNT"

# 要素数だけループ
for i in $(seq 0 $((ELEMENT_COUNT - 1))); do
    

    PAGE_NAME=$(echo "$PAGES" | jq -r ".[$i].page_name")
    echo "----------------------------------------"
    echo "処理中: $PAGE_NAME"

    PAGE_CONTENT=$(cat "$PAGE_NAME.md")
    

    jq -n --arg text "$PAGE_CONTENT" '{"inputText": $text}' > file.json
    aws bedrock-runtime invoke-model \
        --model-id amazon.titan-embed-text-v2:0 \
        --body fileb://file.json \
        --content-type application/json \
        --accept application/json \
        output.json

    jq -c '.embedding' output.json > vector_data.json

    # アップロード用のベクトルJSONを作成
    SOURCE_TEXT=$(jq -n --arg text "$PAGE_CONTENT" '$text')
    cat > vector_upload.json << EOF
[
  {
    "key": "${PAGE_NAME}",
    "data": {
      "float32": $(cat vector_data.json)
    },
    "metadata": {
      "source_text": $SOURCE_TEXT
    }    
  }
]
EOF
    aws s3vectors put-vectors \
        --vector-bucket-name "$VECTOR_BUCKET" \
        --index-name "$VECTOR_INDEX" \
        --vectors file://vector_upload.json

    echo "S3へのベクトル登録完了: ${PAGE_NAME}"
    echo "----------------------------------------"
done

echo "========================================"
echo "全処理完了"
