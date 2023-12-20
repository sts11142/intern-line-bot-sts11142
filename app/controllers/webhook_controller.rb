require 'line/bot'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    events = client.parse_events_from(body)
    events.each { |event|
      session_key = event['source']['userId']

      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          handle_text_message(event, session_key)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }
    head :ok
  end

  private

  def handle_text_message(event, session_key)
    fixed_phrases = {
      greeting: "今日もお疲れさまです。振り返りを始めます。",
      questions: [
        '今日絶対に達成したかったことはなんですか？',
        '今日どんな出来事があって、どう感じましたか？',
        'なぜそう感じたのだと思いますか？',
        'それを学びとして一文で表すとしたら、どのように人に教えますか？',
        '今日をもう一度やり直すとしたら、どうしますか？'
      ]
    }

    case event.message['text']
    when '振り返り'
      # 振り返りを始める（セッションを開始する）
      session[session_key] = { current_question: 1 }
      text = "#{fixed_phrases[:greeting]} \n\n #{fixed_phrases[:questions][0]}"  # 挨拶＋最初の質問
      reply_text(event['replyToken'], text)
    end
  end
  
  def reply_text(reply_token, text)
    message = {
      type: 'text',
      text: text
    }
    client.reply_message(reply_token, message)
  end
end
