require 'line/bot'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  fixed_phrases = {
    greeting: "今日もお疲れさまです。\n振り返りを始めます。",
    questions: [
      '今日絶対に達成したかったことはなんですか？',
      '今日どんな出来事があって、どう感じましたか？',
      'なぜそう感じたのだと思いますか？',
      'それを学びとして一文で表すとしたら、どのように人に教えますか？',
      '今日をもう一度やり直すとしたら、どうしますか？'
    ],
    finishing: "これで質問は終了です\n明日も頑張りましょうね！"
  }

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
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          response_text = handle_text_message(event)

          message = {
            type: 'text',
            text: response_text
          }
          client.reply_message(event['replyToken'], message)
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

  def handle_text_message(event)
    user_id = event['source']['userId']
    user_session = UserSession.find_or_initialize_by(user_id: user_id)
    user_session.current_question ||= 0  # 初期化

    # 振り返りの処理開始
    input_text = event.message['text']
    response_text = ""

    # 振り返りが始まっていないとき(question == 0)
    if user_session.current_question == 0
      if input_text == '振り返り'
        # 振り返りを始める
        user_session.current_question = 1
        user_session.save
        response_text = "#{fixed_phrases[:greeting]} \n\n #{fixed_phrases[:questions][0]}"  # 挨拶＋最初の質問
        return response_text
      elsif input_text != '振り返り'
        # 注意メッセージ送信（まだ振り返りが始まっていない場合のみ）
        response_text = '振り返りを開始するには「振り返り」と入力しましょう'  
        return response_text        
      end
    end

    # 振り返りが始まっているとき(question >= 1)
    next_question = user_session.current_question + 1
    if next_question <= 5
      response_text = fixed_phrases[:questions][user_session.current_question]
      user_session.current_question = next_question
      user_session.save
    elsif next_question > 5
      response_text = fixed_phrases[:finishing]
      user_session.current_question = 0
      user_session.save
    end

    return response_text
  end
end
