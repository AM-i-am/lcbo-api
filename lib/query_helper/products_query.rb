module QueryHelper
  class ProductsQuery < Query

    def initialize(request, params)
      super
      self.q = params[:q] if params[:q].present?
      validate
    end

    def self.table
      :products
    end

    def self.filterable_fields
      %w[
      is_dead
      is_discontinued
      has_value_added_promotion
      has_limited_time_offer
      has_bonus_reward_miles
      is_seasonal
      is_vqa
      is_kosher ]
    end

    def self.sortable_fields
      %w[
      id
      price_in_cents
      regular_price_in_cents
      limited_time_offer_savings_in_cents
      limited_time_offer_ends_on
      bonus_reward_miles
      bonus_reward_miles_ends_on
      package_unit_volume_in_milliliters
      total_package_units
      total_package_volume_in_milliliters
      volume_in_milliliters
      alcohol_content
      price_per_liter_of_alcohol_in_cents
      price_per_liter_in_cents
      inventory_count
      inventory_volume_in_milliliters
      inventory_price_in_cents
      released_on ]
    end

    def self.order
      'inventory_volume_in_milliliters.desc'
    end

    def self.where
      []
    end

    def self.where_not
      %w[ is_dead ]
    end

    def dataset
      case
      when has_fulltext?
        DB[:products].full_text_search([:tags], q)
      else
        DB[:products]
      end.
      filter(filter_hash).
      order(*order)
    end

    def as_csv
      FasterCSV.generate(:encoding => 'UTF-8') do |csv|
        csv << Product.public_fields
        csv_dataset.all do |row|
          csv << Product.as_csv(row)
        end
      end
    end

    def as_json
      h = super
      h[:result] = page_dataset.all.map { |row| Product.as_json(row) }
      h[:suggestion] = if 0 == h[:result].size
        has_fulltext? ? Fuzz[:products, q] : nil
      else
        nil
      end
      h
    end

  end
end
