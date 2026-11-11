# frozen_string_literal: true

ActiveRecord::Base.logger = nil
ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL', 'postgres:///portolan_test'))

begin
  ActiveRecord::Base.connection.verify!
rescue ActiveRecord::NoDatabaseError
  ActiveRecord::Tasks::DatabaseTasks.create(ActiveRecord::Base.connection_db_config)
end

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :ships, force: :cascade do |t|
    t.string :name, null: false
    t.string :flag, null: false
  end

  create_table :captains, force: :cascade do |t|
    t.string :name, null: false
  end

  create_table :voyages, force: :cascade do |t|
    t.references :ship, null: false, foreign_key: true
    t.references :captain, foreign_key: true
    t.string :fleet, null: false
    t.string :harbor, null: false
    t.datetime :departed_at, null: false
    t.datetime :arrived_at
    t.boolean :lost, null: false, default: false
    t.integer :crew, null: false
    t.integer :leagues, null: false
    t.date :charted_on
  end
end
