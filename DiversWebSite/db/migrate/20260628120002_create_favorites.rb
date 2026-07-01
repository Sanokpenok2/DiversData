# frozen_string_literal: true

class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :scientist, null: false, foreign_key: true
      t.bigint :report_id, null: false

      t.timestamps
    end

    add_index :favorites, %i[scientist_id report_id], unique: true
    add_index :favorites, :report_id
  end
end
