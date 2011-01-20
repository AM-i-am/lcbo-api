# Inspired by / ripped from tenderlove's Texticle
module Sequel
  class Dataset

    def search(colnames, rawquery, opts = {})
      query = rawquery.to_s.gsub(/[^\w]+/, ' ').gsub(/\s+/, ' ').strip
      return self if '' == query.to_s
      lang = (opts[:lang] || 'simple')
      cols = Array(colnames).
        map { |c|
          SQL::Function.new(:COALESCE, c, '')
        }.
        sql_string_join(' ')
      filter(%{
        to_tsvector(#{literal lang}, #{literal cols})
        @@
        plainto_tsquery(#{literal lang}, ?)
      }, query)
    end

  end
end
