# frozen_string_literal: true

Sequel.migration do
  up do
    if table_exists?(:user_sessions) && schema(:user_sessions).map(&:first).include?(:telegram_user_id)
      alter_table(:user_sessions) do
        rename_column :telegram_user_id, :max_user_id
      end
    end

    if table_exists?(:reports) && schema(:reports).map(&:first).include?(:telegram_user_id)
      alter_table(:reports) do
        rename_column :telegram_user_id, :max_user_id
        rename_column :telegram_username, :max_username
        rename_column :telegram_first_name, :max_first_name
        rename_column :telegram_last_name, :max_last_name
      end
    end

    if table_exists?(:report_photos) && schema(:report_photos).map(&:first).include?(:telegram_file_id)
      alter_table(:report_photos) do
        rename_column :telegram_file_id, :attachment_token
      end
    end
  end

  down do
    if table_exists?(:user_sessions) && schema(:user_sessions).map(&:first).include?(:max_user_id)
      alter_table(:user_sessions) do
        rename_column :max_user_id, :telegram_user_id
      end
    end

    if table_exists?(:reports) && schema(:reports).map(&:first).include?(:max_user_id)
      alter_table(:reports) do
        rename_column :max_user_id, :telegram_user_id
        rename_column :max_username, :telegram_username
        rename_column :max_first_name, :telegram_first_name
        rename_column :max_last_name, :telegram_last_name
      end
    end

    if table_exists?(:report_photos) && schema(:report_photos).map(&:first).include?(:attachment_token)
      alter_table(:report_photos) do
        rename_column :attachment_token, :telegram_file_id
      end
    end
  end
end
