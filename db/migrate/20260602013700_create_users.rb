class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :access_token, null: false

      t.timestamps
    end

    add_index :users, :name, unique: true
    add_index :users, :access_token, unique: true
  end
end
