class ChangeCurrentQuestionIdDefaultOnLineUsers < ActiveRecord::Migration[6.0]
  def change
    change_column_default :line_users, :current_question_id, from: nil, to: 0
  end
end
