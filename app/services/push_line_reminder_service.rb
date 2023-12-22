require 'net/http'
require 'uri'
require 'json'

LINE_BROADCAST_ENDPOINT = "https://api.line.me/v2/bot/message/broadcast"
REMINDER_MESSAGE = "【リマインド】お疲れさま！\n今日の振り返りをしよう！５分で終わりますよ\n\n振り返りを始める時は「振り返り」と言ってね"

class PushLineReminderService
    def call
        # httpリクエストの設定
        uri = URI.parse(LINE_BROADCAST_ENDPOINT)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # ローカルからリクエストを送るのに必要

        # リクエストの内容を準備
        headers = {
            'Authorization': "Bearer #{ENV["LINE_CHANNEL_TOKEN"]}",
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        params = {
            'messages': [{
                type: 'text',
                text: REMINDER_MESSAGE
            }]
        }

        # LINEブロードキャストapi にリクエストを送信
        http.start do
            req = http.post(uri.path, params.to_json, headers)
        end
    end
end
