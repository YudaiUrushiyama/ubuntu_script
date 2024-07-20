import requests
import feedparser
import json
import os

# RSSフィードURL
FEED_URL = "https://aws.amazon.com/jp/blogs/aws/feed/"

# 最後の投稿IDを保存するファイル
LAST_ENTRY_FILE = "tmp/last_entry.txt"

# configファイル定義
CONFIG_FILE = "config.conf"

def get_value_from_config(key):
    """
    設定ファイルから指定されたキーの値を取得する関数
    """
    # スクリプトのディレクトリを取得
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # 設定ファイルのパスを構築
    config_path = os.path.join(script_dir, 'conf', CONFIG_FILE )

    # 設定ファイルを読み込む
    value = None
    with open(config_path, 'r') as file:
        for line in file:
            if line.startswith(f'{key}='):
                # キーの値を取得し、不要な引用符を削除
                value = line.split('=', 1)[1].strip().strip('"')
                break

    return value

def get_last_entry_id():
    if os.path.exists(LAST_ENTRY_FILE):
        with open(LAST_ENTRY_FILE, 'r') as file:
            return file.read().strip()
    return None

def save_last_entry_id(entry_id):
    with open(LAST_ENTRY_FILE, 'w') as file:
        file.write(entry_id)

def send_slack_notification(message, webhook_url):
    payload = {
        "text": message
    }
    response = requests.post(webhook_url, data=json.dumps(payload),
                             headers={'Content-Type': 'application/json'})
    if response.status_code != 200:
        raise Exception(f"Request to Slack returned an error {response.status_code}, the response is:\n{response.text}")


def main():
    feed = feedparser.parse(FEED_URL)
    url = get_value_from_config('SLACK_URL1')
    if not feed.entries:
        print("No entries found in the feed.")
        return

    last_entry_id = get_last_entry_id()
    latest_entry = feed.entries[0]

    if latest_entry.id != last_entry_id:
        message = f"New AWS Blog Post: {latest_entry.title}\n{latest_entry.link}"
        send_slack_notification(message,url)
        save_last_entry_id(latest_entry.id)
        print("New entry detected and notification sent.")
    else:
        print("No new entries detected.")

if __name__ == "__main__":
    main()

