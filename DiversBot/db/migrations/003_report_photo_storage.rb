# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:report_photos) do
      add_column :source_url, String, text: true
      add_column :storage_path, String, text: true
    end
  end
end
