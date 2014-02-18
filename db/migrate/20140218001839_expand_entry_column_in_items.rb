class ExpandEntryColumnInItems < ActiveRecord::Migration
  def up
    change_column :items, :entry, :text
  end

  def down
    change_column :items, :entry, :string
  end
end
