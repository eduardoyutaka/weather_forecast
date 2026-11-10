# One Address per ZIP code. The unique constraint is what makes concurrent
# lookups of the same ZIP safe (see AddressLookup / create_or_find_by!).
class AddUniqueIndexToAddressesPostalCode < ActiveRecord::Migration[8.1]
  def change
    remove_index :addresses, :postal_code
    add_index :addresses, :postal_code, unique: true
  end
end
