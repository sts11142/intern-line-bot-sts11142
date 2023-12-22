class CreateUserSessions < ActiveRecord::Migration[6.0]
  def change
    create_table :user_sessions do |t|
      t.string :user_id
      t.integer :current_question

      t.timestamps
    end
  end
end
