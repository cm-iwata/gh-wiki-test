#!/bin/bash

set -eo pipefail

# 入力JSONの配列を受け取る
# 例: ./script.sh '[{"text":"bbb"},{"text":"aaa"}]'
INPUT_JSON="$1"

echo "$INPUT_JSON"
# JSONの要素数を取得
ELEMENT_COUNT=$(echo "$INPUT_JSON" | jq 'length')
echo "要素数: $ELEMENT_COUNT"

# 要素数だけループ
for i in $(seq 0 $((ELEMENT_COUNT - 1))); do
    echo "----------------------------------------"
    echo "処理中: インデックス $i"

    # JSON要素を取得
    TEXT=$(echo "$INPUT_JSON" | jq -c ".[$i].text")
    TITLE=$(echo "$INPUT_JSON" | jq -c ".[$i].title")
    echo "要素: $TEXT"

    # Bedrockへの入力ファイルを生成
    echo "{\"inputText\": $TEXT}" > file.json

    # Bedrockでベクトル化
    aws bedrock-runtime invoke-model \
        --model-id amazon.titan-embed-text-v2:0 \
        --body fileb://file.json \
        --content-type application/json \
        --accept application/json \
        output.json

    # jqでベクトルを取得
    jq -c '.embedding' output.json > vector_data.json


    # アップロード用のベクトルJSONを作成
    cat > vector_upload.json << EOF
[
  {
    "key": ${TITLE},
    "data": {
      "float32": $(cat vector_data.json)
    },
    "metadata": {
      "source_text": ${TEXT}
    }
  }
]
EOF
    echo "アップロード用JSON生成完了"

    # S3にベクトルを登録
    aws s3vectors put-vectors \
        --vector-bucket-name "$VECTOR_BUCKET" \
        --index-name "$VECTOR_INDEX" \
        --vectors file://vector_upload.json

    echo "S3へのベクトル登録完了: ${TITLE}"
done

echo "========================================"
echo "全処理完了"
