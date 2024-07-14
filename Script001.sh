#!/bin/bash

# スクリプト名取得
PROGNAME=$(basename $0 .sh)

# プロセスID取得
PROC_ID=$$

# フォルダパス取得
CURRENT_DIR=$(dirname $0)

# configファイル取得
CONFIG_FILE=${CURRENT_DIR}/conf/config.conf
if [ -r ${CONFIG_FILE} ]; then
  . ${CONFIG_FILE}
  # 下記変数の値を使用する
  # SWITCHBOT_TOKEN
  # SWITCHBOT_SERCRET
else
  echo "${CONFIG_FILE} が存在しません。"
  exit 9
fi


# SWITCHBOTパラメータ格納
token=${SWITCHBOT_TOKEN}
secret=${SWITCHBOT_SERCRET}

t=$(date +%s%3N)
nonce=$(uuidgen -r)
sign=$(echo -n ${token}${t}${nonce} | openssl dgst -sha256 -hmac ${secret} -binary | base64)

# Switch全体データ取得
RETRY=0
while [ $RETRY -lt 3 ]; do
  result=$(
      curl -s "https://api.switch-bot.com/v1.1/devices" \
        --header "Authorization: ${token}" \
        --header "sign: ${sign}" \
        --header "t: ${t}" \
        --header "nonce: ${nonce}" \
        --header "Content-Type: application/json; charset=utf8")
  #echo $result
  message=$(echo "$result" | jq -r '.message')
  # echo $message
  # メッセージ確認
  if [ "$message" == "success" ]; then
    break
  fi

  # メッセージで"Internal server error"が返ってきた場合はcurlコマンドリトライ
  RETRY=$((RETRY + 1))
  sleep 1
done

# リトライ後も期待の応答でない場合は処理終了
if [ "$message" != "success" ]; then
    echo "デバイスIDを取得できませんでした。"
    exit 9
fi

# 温湿度デバイスID取得
deviceID=$(echo "$result" | jq -r '.body.deviceList[] | select(.deviceType == "Meter") | .deviceId')

# 対象デバイスの情報取得URL作成
url="https://api.switch-bot.com/v1.1/devices/$deviceID/status"

# 温湿度情報取得　リトライ最大3回
RETRY=0
while [ $RETRY -lt 3 ]; do
  status=$(
      curl -s $url \
        --header "Authorization: ${token}" \
        --header "sign: ${sign}" \
        --header "t: ${t}" \
        --header "nonce: ${nonce}" \
        --header "Content-Type: application/json; charset=utf8")
  # echo $status
  message=$(echo "$status" | jq -r '.message')
  # echo $message
  # メッセージ確認
  if [ "$message" == "success" ]; then
    break
  fi

  # メッセージで"Internal server error"が返ってきた場合はcurlコマンドリトライ
  RETRY=$((RETRY + 1))
  sleep 1
done

# リトライ後も期待の応答でない場合は処理終了
if [ "$message" != "success" ]; then
    echo "温湿度情報を取得できませんでした。"
    exit 9
fi

# jqコマンドを使用して温度と湿度を抽出
temperature=$(echo "$status" | jq -r '.body.temperature')
humidity=$(echo "$status" | jq -r '.body.humidity')

# Slack Webhook URL
WEBHOOK_URL=${SLACK_URL1}

# メッセージ内容
MESSAGE="温度:$temperature°C , 湿度:$humidity%"

# Slackに送信するJSONデータを生成
payload=$(jq -n --arg text "$MESSAGE" '{text: $text}')

# Slackにメッセージを送信
curl -X POST -H 'Content-type: application/json' --data "$payload" $WEBHOOK_URL

exit 0
