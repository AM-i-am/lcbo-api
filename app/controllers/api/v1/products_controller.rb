class API::V1::ProductsController < API::V1::APIController
  def index
    @query = query(:products)

    respond_to do |format|
      format.csv { render text: @query.as_csv }
      format.tsv { render text: @query.as_tsv }
      format.any(:js, :json) { render_json @query.as_json }
    end
  end

  def show
    if params[:id].to_i > 999999
      return unless enforce_feature_flag!(:has_upc_lookup)
    end

    @query = query(:product)

    respond_to do |format|
      format.csv { render text: @query.as_csv }
      format.tsv { render text: @query.as_tsv }
      format.any(:js, :json) { render_json @query.as_json }
    end
  end
end
