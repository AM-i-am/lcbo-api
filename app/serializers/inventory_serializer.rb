class InventorySerializer < ApplicationSerializer
  DUMP_COLS = [
    :product_id,
    :store_id,
    :is_dead,
    :quantity,
    :updated_on,
    :updated_at,
  ]

  attributes *(DUMP_COLS + [
    :product_no,
    :store_no
  ])

  def product_no
    object.product_id
  end

  def store_no
    object.store_id
  end

  def filter(keys)
    if scope == :csv
      keys.delete(:product_no)
      keys.delete(:store_no)
    end

    keys
  end
end
