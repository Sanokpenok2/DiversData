# frozen_string_literal: true

class CreateReportDeletionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :report_deletion_requests do |t|
      t.integer :report_id, null: false
      t.references :requested_by, null: false, foreign_key: { to_table: :scientists }
      t.references :reviewed_by, foreign_key: { to_table: :scientists }
      t.text :reason, null: false
      t.string :status, null: false, default: "pending"
      t.text :admin_note
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :report_deletion_requests, :report_id
    add_index :report_deletion_requests, :status
    add_foreign_key :report_deletion_requests, :reports, column: :report_id, on_delete: :cascade
  end
end
