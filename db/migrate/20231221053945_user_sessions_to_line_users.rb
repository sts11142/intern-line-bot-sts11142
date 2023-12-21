class UserSessionsToLineUsers < ActiveRecord::Migration[6.0]
  def change
    rename_table :user_sessions, :line_users
  end
end
