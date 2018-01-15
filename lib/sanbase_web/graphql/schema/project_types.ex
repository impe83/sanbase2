defmodule SanbaseWeb.Graphql.ProjectTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Ecto, repo: Sanbase.Repo

  import_types SanbaseWeb.Graphql.CustomTypes

  alias SanbaseWeb.Graphql.Resolvers.ProjectResolver

  object :project do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :ticker, :string
    field :logo_url, :string
    field :website_link, :string
    field :btt_link, :string
    field :facebook_link, :string
    field :github_link, :string
    field :reddit_link, :string
    field :twitter_link, :string
    field :whitepaper_link, :string
    field :blog_link, :string
    field :slack_link, :string
    field :linkedin_link, :string
    field :telegram_link, :string
    field :token_address, :string
    field :team_token_wallet, :string
    field :token_decimals, :integer
    field :total_supply, :integer
    field :market_segment, :string do
      resolve &ProjectResolver.market_segment/3
    end
    field :infrastructure, :string do
      resolve &ProjectResolver.infrastructure/3
    end
    field :project_transparency, :boolean
    field :project_transparency_status, :string do
      resolve &ProjectResolver.project_transparency_status/3
    end
    field :project_transparency_description, :string

    field :eth_balance, :decimal do
      resolve &ProjectResolver.eth_balance/3
    end
    field :btc_balance, :decimal do
      resolve &ProjectResolver.btc_balance/3
    end
    # If there is no raw data for any currency for a given ico, then fallback one of the precalculated totals - one of Ico.funds_raised_usd, Ico.funds_raised_btc, Ico.funds_raised_eth (checked in that order)
    field :funds_raised_icos, list_of(:currency_amount) do
      resolve &ProjectResolver.funds_raised_icos/3
    end
    field :roi_usd, :decimal do
      resolve &ProjectResolver.roi_usd/3
    end

    field :coinmarketcap_id, :string
    field :symbol, :string do
      resolve &ProjectResolver.symbol/3
    end
    field :rank, :integer do
      resolve &ProjectResolver.rank/3
    end
    field :price_usd, :decimal do
      resolve &ProjectResolver.price_usd/3
    end
    field :volume_usd, :decimal do
      resolve &ProjectResolver.volume_usd/3
    end
    field :marketcap_usd, :decimal do
      resolve &ProjectResolver.marketcap_usd/3
    end
    field :available_supply, :decimal do
      resolve &ProjectResolver.available_supply/3
    end
    field :total_supply, :decimal do
      resolve &ProjectResolver.total_supply/3
    end
    field :percent_change_1h, :decimal, name: "percent_change1h" do
      resolve &ProjectResolver.percent_change_1h/3
    end
    field :percent_change_24h, :decimal, name: "percent_change24h" do
      resolve &ProjectResolver.percent_change_24h/3
    end
    field :percent_change_7d, :decimal, name: "percent_change7d" do
      resolve &ProjectResolver.percent_change_7d/3
    end

    field :initial_ico, :ico do
      resolve &ProjectResolver.initial_ico/3
    end
    field :icos, list_of(:ico), resolve: assoc(:icos)
  end

  object :project_listing do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :ticker, :string
    field :logo_url, :string
    field :website_link, :string
    field :btt_link, :string
    field :facebook_link, :string
    field :github_link, :string
    field :reddit_link, :string
    field :twitter_link, :string
    field :whitepaper_link, :string
    field :blog_link, :string
    field :slack_link, :string
    field :linkedin_link, :string
    field :telegram_link, :string
    field :token_address, :string
    field :team_token_wallet, :string
    field :token_decimals, :integer
    field :total_supply, :integer
    field :market_segment, :string do
      resolve &ProjectResolver.market_segment/3
    end
    field :infrastructure, :string do
      resolve &ProjectResolver.infrastructure/3
    end
    field :project_transparency, :boolean
    field :project_transparency_status, :string do
      resolve &ProjectResolver.project_transparency_status/3
    end
    field :project_transparency_description, :string

    field :coinmarketcap_id, :string
    field :symbol, :string do
      resolve &ProjectResolver.symbol/3
    end
    field :rank, :integer do
      resolve &ProjectResolver.rank/3
    end
    field :price_usd, :decimal do
      resolve &ProjectResolver.price_usd/3
    end
    field :volume_usd, :decimal do
      resolve &ProjectResolver.volume_usd/3
    end
    field :marketcap_usd, :decimal do
      resolve &ProjectResolver.marketcap_usd/3
    end
    field :available_supply, :decimal do
      resolve &ProjectResolver.available_supply/3
    end
    field :total_supply, :decimal do
      resolve &ProjectResolver.total_supply/3
    end
    field :percent_change_1h, :decimal, name: "percent_change1h" do
      resolve &ProjectResolver.percent_change_1h/3
    end
    field :percent_change_24h, :decimal, name: "percent_change24h" do
      resolve &ProjectResolver.percent_change_24h/3
    end
    field :percent_change_7d, :decimal, name: "percent_change7d" do
      resolve &ProjectResolver.percent_change_7d/3
    end
  end

  object :project_public do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :ticker, :string
    field :logo_url, :string
    field :website_link, :string
    field :btt_link, :string
    field :facebook_link, :string
    field :github_link, :string
    field :reddit_link, :string
    field :twitter_link, :string
    field :whitepaper_link, :string
    field :blog_link, :string
    field :slack_link, :string
    field :linkedin_link, :string
    field :telegram_link, :string
    field :token_address, :string
    field :team_token_wallet, :string
    field :token_decimals, :integer
    field :total_supply, :integer
    field :market_segment, :string do
      resolve &ProjectResolver.market_segment/3
    end
    field :infrastructure, :string do
      resolve &ProjectResolver.infrastructure/3
    end
    field :project_transparency, :boolean
    field :project_transparency_status, :string do
      resolve &ProjectResolver.project_transparency_status/3
    end
    field :project_transparency_description, :string

    field :eth_balance, :decimal do
      resolve &ProjectResolver.eth_balance/3
    end
    field :btc_balance, :decimal do
      resolve &ProjectResolver.btc_balance/3
    end
    # If there is no raw data for any currency for a given ico, then fallback one of the precalculated totals - one of Ico.funds_raised_usd, Ico.funds_raised_btc, Ico.funds_raised_eth (checked in that order)
    field :funds_raised_icos, list_of(:currency_amount) do
      resolve &ProjectResolver.funds_raised_icos/3
    end
    field :roi_usd, :decimal do
      resolve &ProjectResolver.roi_usd/3
    end

    field :coinmarketcap_id, :string
    field :symbol, :string do
      resolve &ProjectResolver.symbol/3
    end
    field :rank, :integer do
      resolve &ProjectResolver.rank/3
    end
    field :price_usd, :decimal do
      resolve &ProjectResolver.price_usd/3
    end
    field :volume_usd, :decimal do
      resolve &ProjectResolver.volume_usd/3
    end
    field :marketcap_usd, :decimal do
      resolve &ProjectResolver.marketcap_usd/3
    end
    field :available_supply, :decimal do
      resolve &ProjectResolver.available_supply/3
    end
    field :total_supply, :decimal do
      resolve &ProjectResolver.total_supply/3
    end
    field :percent_change_1h, :decimal, name: "percent_change1h" do
      resolve &ProjectResolver.percent_change_1h/3
    end
    field :percent_change_24h, :decimal, name: "percent_change24h" do
      resolve &ProjectResolver.percent_change_24h/3
    end
    field :percent_change_7d, :decimal, name: "percent_change7d" do
      resolve &ProjectResolver.percent_change_7d/3
    end
  end

  object :project_with_eth_contract_info do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :ticker, :string

    field :initial_ico, :ico_with_eth_contract_info do
      resolve &ProjectResolver.initial_ico/3
    end
  end

  object :ico do
    field :id, non_null(:id)
    field :start_date, :ecto_date
    field :end_date, :ecto_date
    field :token_usd_ico_price, :decimal
    field :token_eth_ico_price, :decimal
    field :token_btc_ico_price, :decimal
    field :tokens_issued_at_ico, :decimal
    field :tokens_sold_at_ico, :decimal
    field :funds_raised_btc, :decimal
    field :funds_raised_usd, :decimal
    field :funds_raised_eth, :decimal
    field :minimal_cap_amount, :decimal
    field :maximal_cap_amount, :decimal
    field :main_contract_address, :string
    field :contract_block_number, :integer
    field :contract_abi, :string
    field :comments, :string
    field :cap_currency, :string do
      resolve &ProjectResolver.ico_cap_currency/3
    end
    field :currency_amounts, list_of(:currency_amount) do
      resolve &ProjectResolver.ico_currency_amounts/3
    end
  end

  object :ico_with_eth_contract_info do
    field :id, non_null(:id)
    field :start_date, :ecto_date
    field :end_date, :ecto_date
    field :main_contract_address, :string
    field :contract_block_number, :integer
    field :contract_abi, :string
  end

  object :currency_amount do
    field :currency_code, :string
    field :amount, :decimal
  end
end
