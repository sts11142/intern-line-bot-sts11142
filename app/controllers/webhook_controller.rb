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
    fixed_phrases = {
      greeting: "今日も良い一日でしたね！\nさっそく振り返りを始めましょう！！",
      interrupting: "一度中断しますね。\n再開する時は、「振り返り」と入力してください！",
      finishing: "これで質問は終了です！とても良い学びでした\nですが無理は禁物です。\n\n明日も頑張りましょうね！",
      warning: '振り返りを開始するには「振り返り」と入力しましょう',
      questions: [
        '今日、絶対に達成したかったことはなんでしたか？',
        '今日はどんな出来事があって、どう感じましたか？教えてください！',
        'なぜそう感じたのだと思いますか？',
        'これを学びとして一文で表すとしたら、どのように人に教えましょうか...',
        '今日をもう一度やり直すとしたら、どんなことをしたいですか？'
      ]
    }
  
    user_id = event['source']['userId']
    user_session = UserSession.find_or_initialize_by(user_id: user_id)
    user_session.current_question ||= 0  # 初期化

    # 振り返りの処理開始
    input_text = event.message['text']
    response_text = ""

    # 例外処理（中断）
    if input_text == '中断'
      response_text = fixed_phrases[:interrupting]
      set_and_save_question_to(user_session, 0)
      return response_text
    end

    # 振り返りを行う
    # 振り返りが始まっていないとき(question == 0)
    if user_session.current_question == 0
      if input_text == '振り返り'
        # 開始の挨拶をする（後で質問を加える）
        response_text = "#{fixed_phrases[:greeting]} \n\n"  # 挨拶
      elsif input_text != '振り返り'
        # 注意メッセージ送信（まだ振り返りが始まっていない場合のみ）
        response_text = fixed_phrases[:warning]
        return response_text        
      end
    end

    # 振り返りが始まっているとき(question >= 1)
    next_question = user_session.current_question + 1
    if next_question <= fixed_phrases[:questions].length
      # 質問を継続する
      response_text << fixed_phrases[:questions][user_session.current_question]
      set_and_save_question_to(user_session, next_question)
    elsif next_question > fixed_phrases[:questions].length
      # 終了を伝える
      response_text = fixed_phrases[:finishing]
      set_and_save_question_to(user_session, 0)
    end

    return response_text
  end

  def set_and_save_question_to(user_session, number)
    user_session.current_question = nunmber
    user_session.save
  end
end
