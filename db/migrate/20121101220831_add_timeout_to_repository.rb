class AddTimeoutToRepository < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :timeout, :integer, :default => 40
  end
end
