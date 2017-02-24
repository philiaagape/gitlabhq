# rubocop:disable all
class CreateUsersGroups < ActiveRecord::Migration
  DOWNTIME = false

  def change
    create_table :users_groups do |t|
      t.integer :group_access, null: false
      t.integer :group_id, null: false
      t.integer :user_id, null: false

      t.timestamps null: true
    end
  end
end
