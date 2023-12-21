class RenameUserIdColumnToUserSessions < ActiveRecord::Migration[6.0]
  def change
    rename_column :user_sessions, :user_id, :line_user_id
  end
end
