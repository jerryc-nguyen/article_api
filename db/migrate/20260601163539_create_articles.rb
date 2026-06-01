class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.string :status, default: "draft", null: false
      t.text :parsed_fields
      t.integer :fields_version, default: 1, null: false
      t.text :original_content
      t.string :content_hash

      t.timestamps
    end
  end
end
