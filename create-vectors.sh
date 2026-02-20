#!/bin/bash

set -eo pipefail
pwd
# [
#   {
#     "action": "edited",
#     "html_url": "https://github.com/cm-iwata/gh-wiki-test/wiki/new-page",
#     "page_name": "new-page",
#     "sha": "1de83f1bae8e478ef1cb8d8a626cf2af554afe64",
#     "summary": null,
#     "title": "new page"
#   }
# ]

PAGES="$1"

echo "$PAGES"
# JSONの要素数を取得
ELEMENT_COUNT=$(echo "$PAGES" | jq 'length')
echo "要素数: $ELEMENT_COUNT"

# 要素数だけループ
for i in $(seq 0 $((ELEMENT_COUNT - 1))); do
    echo "----------------------------------------"
    echo "処理中: インデックス $i"

    # JSON要素を取得
    PAGE_NAME=$(echo "$PAGES" | jq -r ".[$i].page_name")
    TEXT=$(cat "$PAGE_NAME")
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
