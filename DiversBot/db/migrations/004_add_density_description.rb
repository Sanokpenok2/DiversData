# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:reports) do
      add_column :density_description, String, text: true
    end
  end
end
