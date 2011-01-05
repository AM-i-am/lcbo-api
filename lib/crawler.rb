class Crawler < Boticus::Bot

  class UnknownJobTypeError < StandardError; end

  class ProductListsGetter
    include LCBO::CrawlKit::Crawler

    def request(params)
      LCBO.product_list(params[:next_page] || 1)
    end

    def continue?(current_params)
      current_params[:next_page] ? true : false
    end

    def reduce
      responses.map { |params| params[:product_nos] }.flatten
    end
  end

  def init(crawl = nil)
    @model = (crawl || Crawl.init)
  end

  def log(level, msg, payload = {})
    super
    model.log(msg, level, payload)
  end

  def prepare
    log :info, 'Enumerating product job queue ...'
    model.push_jobs(:product, ProductListsGetter.run)
    log :info, 'Enumerating store job queue ...'
    model.push_jobs(:store, LCBO.store_list[:store_nos])
  end

  desc 'Crawling stores, products, and inventories'
  task :crawl do
    while (model.is?(:running) && pair = model.popjob)
      case pair[0]
        when 'product' then place_product_and_inventories(pair[1])
        when 'store'   then place_store(pair[1])
      end
      model.total_finished_jobs += 1
      model.save
    end
    puts
  end

  desc 'Refreshing fuzzy search dictionaries'
  task :recache_fuzz do
    Fuzz.recache
  end

  desc 'Performing calculations'
  task :calculate do
    DB << <<-SQL
      UPDATE stores SET
        products_count = (
          SELECT COUNT(inventories.product_id)
            FROM inventories
           WHERE inventories.store_id = stores.id
        ),
        inventory_count = (
          SELECT SUM(inventories.quantity)
            FROM inventories
           WHERE inventories.store_id = stores.id
        ),
        inventory_price_in_cents = (
          SELECT SUM(inventories.quantity * products.price_in_cents)
            FROM products
              LEFT JOIN inventories ON products.id = inventories.product_id
           WHERE inventories.store_id = stores.id
        ),
        inventory_volume_in_milliliters = (
          SELECT SUM(inventories.quantity * products.volume_in_milliliters)
            FROM products
              LEFT JOIN inventories ON products.id = inventories.product_id
           WHERE inventories.store_id = stores.id
        )
    SQL
  end

  desc 'Performing diff'
  task :diff do
    model.diff!
  end

  desc 'Marking dead products'
  task :mark_dead_products do
    DB[:products].
      filter(:id => model.removed_product_nos).
      update(:is_dead => true)
  end

  desc 'Marking dead stores'
  task :mark_dead_stores do
    DB[:stores].
      filter(:id => model.removed_store_nos).
      update(:is_dead => true)
  end

  desc 'Marking dead inventories'
  task :mark_dead_inventories do
    DB[:inventories].
      filter(
        { :product_id => model.removed_product_nos } |
        { :store_id => model.removed_store_nos}
      ).
      update(:is_dead => true)
  end

  desc 'Committing stores'
  task :commit_stores do
    Store.commit(model.id)
  end

  desc 'Committing products'
  task :commit_products do
    Product.commit(model.id)
  end

  desc 'Committing inventories'
  task :commit_inventories do
    Inventory.commit(model.id)
  end

  desc 'Flushing page caches'
  task :flush_caches do
    LCBOAPI.flush
  end

  def place_store(store_no)
    attrs = LCBO.store(store_no)
    attrs[:is_dead] = false
    attrs[:crawl_id] = model.id
    Store.place(attrs)
    log :dot, "Placed store: #{store_no}"
    model.total_stores += 1
    model.save
    model.crawled_store_nos << store_no
    log :dot, "Placed store ##{store_no}"
  rescue LCBO::CrawlKit::NotFoundError
    log :warn, "Skipping store ##{store_no}, it does not exist."
  end

  # TODO: Make this not so beastly!
  def place_product_and_inventories(product_no)
    pa = LCBO.product(product_no)
    ia = LCBO.inventory(product_no)
    ia[:inventory_count].tap do |count|
      pa.tap do |p|
        p[:crawl_id] = model.id
        p[:is_dead] = false
        p[:inventory_count] = count
        p[:inventory_price_in_cents] = (p[:price_in_cents] * count)
        p[:inventory_volume_in_milliliters] = (p[:volume_in_milliliters] * count)
      end
    end
    Product.place(pa)
    ia[:inventories].each do |inv|
      inv[:crawl_id] = model.id
      inv[:is_dead] = false
      inv[:product_no] = product_no
      Inventory.place(inv)
    end
    model.total_products += 1
    model.total_inventories += ia[:inventories].size
    model.total_product_inventory_count += ia[:inventory_count]
    model.total_product_inventory_price_in_cents += pa[:inventory_price_in_cents]
    model.total_product_inventory_volume_in_milliliters += pa[:inventory_volume_in_milliliters]
    model.save
    model.crawled_product_nos << product_no
    log :dot, "Placed product ##{product_no} and #{ia[:inventories].size} inventories"
  rescue LCBO::CrawlKit::NotFoundError
    log :warn, "Skipping product ##{product_no}, it does not exist"
  end

end
