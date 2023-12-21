class RenameCurrentQuestionColumnToUserSessions < ActiveRecord::Migration[6.0]
  def change
    rename_column :user_sessions, :current_question, :current_question_id
  end
end
