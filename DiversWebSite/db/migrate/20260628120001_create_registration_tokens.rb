# frozen_string_literal: true

class CreateRegistrationTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :registration_tokens do |t|
      t.string :token, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :scientists }
      t.references :used_by, foreign_key: { to_table: :scientists }
      t.datetime :used_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :registration_tokens, :token, unique: true
  end
end
