# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:user_sessions) do
      primary_key :id
      Bignum :max_user_id, null: false, unique: true
      String :state, null: false, default: 'idle'
      column :data, :jsonb, null: false, default: Sequel.pg_jsonb({})
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end

    create_table(:reports) do
      primary_key :id
      Bignum :max_user_id, null: false
      String :max_username
      String :max_first_name
      String :max_last_name
      Date :observation_date, null: false
      String :location_type, null: false
      Float :latitude
      Float :longitude
      String :location_description, text: true
      String :encounter_type, null: false
      Float :encounter_radius_m
      Float :depth_m, null: false
      TrueClass :depth_is_approximate, null: false, default: true
      String :substrate_type, null: false, text: true
      String :additional_info, text: true
      String :status, null: false, default: 'submitted'
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :max_user_id
      index :observation_date
      index :created_at
    end

    create_table(:report_photos) do
      primary_key :id
      foreign_key :report_id, :reports, null: false, on_delete: :cascade
      String :attachment_token, null: false
      String :photo_type, null: false
      String :caption, text: true
      DateTime :created_at, null: false

      index :report_id
    end
  end
end
