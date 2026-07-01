# frozen_string_literal: true

class CreateScientists < ActiveRecord::Migration[8.1]
  def change
    create_table :scientists do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "scientist"

      t.timestamps
    end

    add_index :scientists, :email, unique: true
    add_index :scientists, :role
  end
end
