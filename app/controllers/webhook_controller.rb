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

  INITIAL_QUESTION_ID = 0.freeze
  FIXED_PHRASES = {
      greeting: "今日も良い一日でしたね！\nさっそく振り返りを始めましょう！！",
      interrupting: "一度中断しますね。\n再開する時は、「振り返り」と入力してください！",
      finishing: "これで質問は終了です、とても良い学びでしたね！\n\n明日も良い一日にしましょう！",
      warning: "メッセージありがとうございます！\n振り返りを開始するには「振り返り」と入力しましょう",
      questions: [
        '今日、絶対に達成したかったことはなんでしたか？',
        "今日はどんな出来事があって、どう感じましたか？\nぜひ教えてください！",
        'なぜそう感じたのだと思いますか？？',
        'この学びを一文で表しましょう！',
        '今日をもう一度やり直すとしたら、何をしたいですか？'
      ]
    }.freeze

  def handle_text_message(event)
    line_user_id = event['source']['userId']
    line_user = LineUser.find_or_initialize_by(line_user_id: line_user_id)
    line_user.current_question_id ||= INITIAL_QUESTION_ID  # 初期化

    # 振り返りの処理開始
    input_text = event.message['text']
    response_text = process_message_of(line_user, input_text)

    return response_text
  end

  def process_message_of(line_user, input_text)
    # TODO: 定数の位置
    # TODO: 中間処理の簡潔化
        response_text = ""

    # 例外処理（中断）
    if input_text == '中断'
      response_text = FIXED_PHRASES[:interrupting]
      set_and_save_question(line_user, INITIAL_QUESTION_ID)
      return response_text
    end

    # 振り返りを行う
    # 振り返りが始まっていないとき(question == 0)
    if line_user.current_question_id == INITIAL_QUESTION_ID
      if input_text == '振り返り'
        # 開始の挨拶をする（後で質問を加える）
        response_text = "#{FIXED_PHRASES[:greeting]} \n\n"  # 挨拶
      elsif input_text != '振り返り'
        # 注意メッセージ送信（まだ振り返りが始まっていない場合のみ）
        response_text = "#{FIXED_PHRASES[:warning]}"
        return response_text        
      end
    end

    # 振り返りが始まっているとき(question >= 1)
    next_question = line_user.current_question_id + 1

    if next_question <= FIXED_PHRASES[:questions].length
      # 質問を継続する
      response_text += "#{FIXED_PHRASES[:questions][line_user.current_question_id]}"  # 挨拶文に質問文を追加する形
      set_and_save_question(line_user, next_question)
    elsif next_question > FIXED_PHRASES[:questions].length
      # 終了を伝える
      response_text = "#{FIXED_PHRASES[:finishing]}"
      set_and_save_question(line_user, INITIAL_QUESTION_ID)
    end
    
    return response_text
  end

  def set_and_save_question(line_user, number)
    line_user.current_question_id = number
    line_user.save
  end
end
