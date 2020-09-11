defmodule Sanbase.Model.Project do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias Sanbase.Repo

  alias Sanbase.Model.{
    ProjectEthAddress,
    ProjectBtcAddress,
    Ico,
    Currency,
    MarketSegment,
    Infrastructure,
    LatestCoinmarketcapData
  }

  import Ecto.Query

  @preloads [:eth_addresses, :latest_coinmarketcap_data, :github_organizations]

  schema "project" do
    field(:name, :string)
    field(:coinmarketcap_id, :string)
    field(:ticker, :string)
    field(:logo_url, :string)
    field(:dark_logo_url, :string)
    field(:website_link, :string)
    field(:email, :string)
    field(:btt_link, :string)
    field(:facebook_link, :string)
    field(:github_link, :string)
    field(:reddit_link, :string)
    field(:twitter_link, :string)
    field(:whitepaper_link, :string)
    field(:blog_link, :string)
    field(:slack_link, :string)
    field(:linkedin_link, :string)
    field(:telegram_link, :string)
    field(:token_address, :string)
    field(:team_token_wallet, :string)
    field(:token_decimals, :integer)
    field(:total_supply, :decimal)
    field(:description, :string)
    field(:long_description, :string)
    field(:main_contract_address, :string)
    field(:is_hidden, :boolean, default: false)

    has_one(:social_volume_query, Project.SocialVolumeQuery)

    has_many(:contract_addresses, Project.ContractAddress)
    has_many(:source_slug_mappings, Project.SourceSlugMapping)
    has_many(:icos, Ico)
    has_many(:github_organizations, Project.GithubOrganization)
    has_many(:eth_addresses, ProjectEthAddress)
    has_many(:btc_addresses, ProjectBtcAddress)
    has_many(:chart_configurations, Sanbase.Chart.Configuration, on_delete: :delete_all)

    belongs_to(:market_segment, MarketSegment, on_replace: :nilify)
    belongs_to(:infrastructure, Infrastructure, on_replace: :nilify)

    belongs_to(
      :latest_coinmarketcap_data,
      LatestCoinmarketcapData,
      foreign_key: :slug,
      references: :coinmarketcap_id,
      type: :string,
      on_replace: :nilify
    )

    many_to_many(
      :market_segments,
      MarketSegment,
      join_through: "project_market_segments",
      on_replace: :delete,
      on_delete: :delete_all
    )
  end

  def changeset(%Project{} = project, attrs \\ %{}) do
    project
    |> cast(attrs, [
      :blog_link,
      :btt_link,
      :coinmarketcap_id,
      :dark_logo_url,
      :description,
      :email,
      :facebook_link,
      :github_link,
      :infrastructure_id,
      :is_hidden,
      :linkedin_link,
      :logo_url,
      :long_description,
      :main_contract_address,
      :market_segment_id,
      :name,
      :reddit_link,
      :slack_link,
      :slug,
      :team_token_wallet,
      :telegram_chat_id,
      :telegram_link,
      :ticker,
      :token_address,
      :token_decimals,
      :total_supply,
      :twitter_link,
      :website_link,
      :whitepaper_link
    ])
    |> cast_assoc(:market_segments)
    |> validate_required([:name])
    |> unique_constraint(:slug)
  end

  defdelegate roi_usd(project), to: Project.Roi

  defdelegate ico_price(project), to: Project.FundsRaised

  defdelegate initial_ico(project), to: Project.FundsRaised

  defdelegate funds_raised_usd_ico_end_price(project), to: Project.FundsRaised

  defdelegate funds_raised_eth_ico_end_price(project), to: Project.FundsRaised

  defdelegate funds_raised_btc_ico_end_price(project), to: Project.FundsRaised

  defdelegate funds_raised_icos(project), to: Project.FundsRaised

  defdelegate describe(project), to: Project.Description

  defdelegate contract_info_infrastructure_by_slug(slug), to: Project.ContractData

  defdelegate contract_info_by_slug(slug), to: Project.ContractData

  defdelegate contract_info(project), to: Project.ContractData

  defdelegate contract_address(project), to: Project.ContractData
  defdelegate contract_addresses(project), to: Project.ContractData

  defdelegate has_contract_address?(project), to: Project.ContractData

  defdelegate twitter_handle(project), to: Project.TwitterData

  def coinmarketcap_id(%Project{source_slug_mappings: []}), do: nil

  def coinmarketcap_id(%Project{source_slug_mappings: [_ | _] = source_slug_mappings}) do
    case Enum.find(source_slug_mappings, &(&1.source == "coinmarketcap")) do
      nil -> nil
      %_{slug: slug} -> slug
    end
  end

  def coinmarketcap_id(%Project{} = project) do
    Project.SourceSlugMapping.get_slug(project, "coinmarketcap")
  end

  def sanbase_link(%Project{slug: slug}) when not is_nil(slug) do
    SanbaseWeb.Endpoint.frontend_url() <> "/projects/#{slug}"
  end

  def supply(%Project{} = project) do
    case get_supply(project) do
      nil -> nil
      s -> Decimal.to_float(s)
    end
  end

  defp get_supply(%Project{total_supply: ts, latest_coinmarketcap_data: nil}), do: ts

  defp get_supply(%Project{total_supply: ts, latest_coinmarketcap_data: lcd}) do
    lcd.available_supply || lcd.total_supply || ts
  end

  @doc ~s"""
  Return a project with a matching ticker. `Repo.one` fails if there are more
  than one project with the same ticker.
  """
  @spec by_currency(%Currency{}) :: %Project{} | nil
  def by_currency(%Currency{code: code}) do
    from(
      p in Project,
      where: p.ticker == ^code and not is_nil(p.slug)
    )
    |> Repo.one()
  end

  def id_by_slug(slug) do
    from(p in __MODULE__, where: p.slug == ^slug, select: p.id) |> Repo.one()
  end

  def by_slug(slug, opts \\ [])

  def by_slug(slug, opts) when is_binary(slug) do
    Project
    |> where([p], p.slug == ^slug)
    |> preload_query(opts)
    |> Repo.one()
  end

  def by_slug(slugs, opts) when is_list(slugs) do
    Project
    |> where([p], p.slug in ^slugs)
    |> preload_query(opts)
    |> Repo.all()
  end

  def by_id(id, opts \\ []) when is_integer(id) or is_binary(id) do
    Project
    |> where([p], p.id == ^id)
    |> preload_query(opts)
    |> Repo.one()
  end

  def ticker_by_slug(nil), do: nil
  def ticker_by_slug("TOTAL_MARKET"), do: "TOTAL_MARKET"

  def ticker_by_slug(slug) when is_binary(slug) do
    from(
      p in Sanbase.Model.Project,
      where: p.slug == ^slug and not is_nil(p.ticker),
      select: p.ticker
    )
    |> Sanbase.Repo.one()
  end

  def slug_by_ticker(nil), do: nil
  def slug_by_ticker("TOTAL_MARKET"), do: "TOTAL_MARKET"

  def slug_by_ticker(ticker) do
    from(
      p in Project,
      where: p.ticker == ^ticker and not is_nil(p.slug),
      select: p.slug
    )
    |> Repo.all()
    |> List.first()
  end

  def tickers_by_slug_list(slugs_list) when is_list(slugs_list) do
    from(
      p in Sanbase.Model.Project,
      where: p.slug in ^slugs_list and not is_nil(p.ticker),
      select: {p.ticker, p.slug}
    )
    |> Sanbase.Repo.all()
  end

  def eth_addresses(%Project{} = project) do
    project =
      project
      |> Repo.preload([:eth_addresses])

    addresses =
      project.eth_addresses
      |> Enum.map(fn %{address: address} -> address end)

    {:ok, addresses}
  end

  def eth_addresses(projects) when is_list(projects) do
    ids = for %Project{id: id} <- projects, do: id

    addresses =
      from(
        p in Project,
        where: p.id in ^ids,
        preload: [:eth_addresses]
      )
      |> Repo.all()
      |> Enum.map(fn %Project{eth_addresses: project_eth_addresses} ->
        project_eth_addresses
        |> Enum.map(fn %ProjectEthAddress{address: address} -> address end)
      end)
      |> Enum.reject(fn x -> x == [] end)

    {:ok, addresses}
  end

  @doc """
  Return all projects from the list which trading volume is over a given threshold
  """
  def projects_over_volume_threshold(projects, volume_threshold) do
    case Sanbase.Price.slugs_with_volume_over(volume_threshold) do
      {:ok, slugs_with_volume_over} ->
        slugs_with_volume_over_mapset =
          slugs_with_volume_over
          |> MapSet.new()

        projects |> Enum.filter(fn %{slug: slug} -> slug in slugs_with_volume_over_mapset end)

      _ ->
        {:error, "Cannot filter projects with volume over threshold"}
    end
  end

  def github_organizations(slug) when is_binary(slug) do
    case id_by_slug(slug) do
      nil ->
        {:error,
         "Cannot fetch github organizations for #{slug}. Reason: There is no project with that slug."}

      id ->
        {:ok, Project.GithubOrganization.organizations_of(id)}
    end
  end

  def github_organizations(%Project{} = project) do
    {:ok, project |> Project.GithubOrganization.organizations_of()}
  end

  @doc ~s"""
  Return the real infrastructure code
  If the infrastructure is set to `own` in the database it will use the contract.
  Ethereum has ETH as contract, Bitcoin has BTC and so on, which is the real one,
  """
  def infrastructure_real_code(%Project{} = project) do
    case infrastructure(project) do
      %{code: code} when is_binary(code) ->
        case String.downcase(code) do
          "own" ->
            with {:ok, contract, _} <- contract_info(project), do: {:ok, contract}

          _ ->
            {:ok, code}
        end

      _ ->
        {:ok, nil}
    end
  end

  def infrastructure(%Project{} = project) do
    %Project{infrastructure: infrastructure} = project |> Repo.preload(:infrastructure)
    infrastructure
  end

  def is_erc20?(%Project{} = project) do
    project
    |> Repo.preload([:infrastructure, :contract_addresses])
    |> case do
      %Project{contract_addresses: [_ | _], infrastructure: %Infrastructure{code: "ETH"}} ->
        true

      _ ->
        false
    end
  end

  def is_currency?(%Project{} = project) do
    not is_erc20?(project)
  end

  def is_trending?(%Project{} = project, trending_words_mapset) do
    # Project is trending if the intersection of [name, ticker, slug]
    # and the trending words is not empty
    [project.ticker, project.name, project.slug]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.downcase/1)
    |> MapSet.new()
    |> MapSet.intersection(trending_words_mapset)
    |> Enum.any?()
  end

  def preloads(), do: @preloads

  def preload_assocs(projects, opts \\ []) do
    case Keyword.get(opts, :only_preload) do
      preloads when is_list(preloads) ->
        Repo.preload(projects, preloads)

      nil ->
        additional_preloads = Keyword.get(opts, :additional_preloads, [])
        Repo.preload(projects, additional_preloads ++ @preloads)
    end
  end

  defp preload_query(query, opts) do
    case Keyword.get(opts, :preload?, true) do
      false ->
        query

      true ->
        case Keyword.get(opts, :only_preload) do
          preloads when is_list(preloads) ->
            query
            |> preload(^preloads)

          nil ->
            additional_preloads = Keyword.get(opts, :additional_preloads, [])

            query
            |> preload(^(additional_preloads ++ @preloads))
        end
    end
  end
end
