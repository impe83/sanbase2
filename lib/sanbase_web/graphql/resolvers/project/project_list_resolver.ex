defmodule SanbaseWeb.Graphql.Resolvers.ProjectListResolver do
  require Logger

  import Sanbase.DateTimeUtils

  alias Sanbase.Model.Project

  @spec all_projects(any, map, any) :: {:ok, any}
  def all_projects(_parent, args, _resolution) do
    get_projects(args, :projects_page, :projects)
  end

  def all_erc20_projects(_root, args, _resolution) do
    get_projects(args, :erc20_projects_page, :erc20_projects)
  end

  def all_currency_projects(_root, args, _resolution) do
    get_projects(args, :currency_projects_page, :currency_projects)
  end

  defp get_projects(args, paged_fun, fun) do
    page = Map.get(args, :page)
    page_size = Map.get(args, :page_size)
    opts = args_to_opts(args)

    projects =
      if page_arguments_valid?(page, page_size) do
        apply(Project.List, paged_fun, [page, page_size, opts])
      else
        apply(Project.List, fun, [opts])
      end

    {:ok, projects}
  end

  def all_projects_by_function(_root, %{function: function}, _resolution) do
    with {:ok, function} <- Sanbase.WatchlistFunction.cast(function),
         projects when is_list(projects) <- Sanbase.WatchlistFunction.evaluate(function) do
      {:ok, projects}
    end
  end

  def all_projects_by_ticker(_root, %{ticker: ticker}, _resolution) do
    {:ok, Project.List.projects_by_ticker(ticker)}
  end

  def projects_count(_root, args, _resolution) do
    opts = args_to_opts(args)

    {:ok,
     %{
       erc20_projects_count: Project.List.erc20_projects_count(opts),
       currency_projects_count: Project.List.currency_projects_count(opts),
       projects_count: Project.List.projects_count(opts)
     }}
  end

  # Private functions

  defp page_arguments_valid?(page, page_size) when is_integer(page) and is_integer(page_size) do
    page > 0 and page_size > 0
  end

  defp page_arguments_valid?(_, _), do: false

  defp args_to_opts(args) do
    filters = get_in(args, [:selector, :filters])
    order_by = get_in(args, [:selector, :order_by])
    pagination = get_in(args, [:selector, :pagination])

    included_slugs = filters |> included_slugs_by_filters()
    ordered_slugs = order_by |> ordered_slugs_by_order_by(included_slugs)

    [
      has_selector?: not is_nil(args[:selector]),
      has_order?: not is_nil(order_by),
      has_filters?: not is_nil(filters),
      has_pagination?: not is_nil(pagination),
      pagination: pagination,
      min_volume: Map.get(args, :min_volume),
      included_slugs: included_slugs,
      ordered_slugs: ordered_slugs
    ]
  end

  defp included_slugs_by_filters(nil), do: :all
  defp included_slugs_by_filters([]), do: :all

  defp included_slugs_by_filters(filters) when is_list(filters) do
    filters
    |> Sanbase.Parallel.map(
      fn filter ->
        cache_key =
          {:included_slugs_by_filters,
           %{filter | from: round_datetime(filter.from), to: round_datetime(filter.to)}}
          |> Sanbase.Cache.hash()

        {:ok, slugs} =
          Sanbase.Cache.get_or_store(cache_key, fn ->
            Sanbase.Metric.slugs_by_filter(
              filter.metric,
              filter.from,
              filter.to,
              filter.operator,
              filter.threshold,
              filter.aggregation
            )
          end)

        slugs |> MapSet.new()
      end,
      ordered: false,
      max_concurrency: 8
    )
    |> Enum.reduce(&MapSet.intersection(&1, &2))
    |> Enum.to_list()
  end

  defp ordered_slugs_by_order_by(nil, slugs), do: slugs

  defp ordered_slugs_by_order_by(order_by, slugs) do
    %{metric: metric, from: from, to: to, direction: direction} = order_by
    aggregation = Map.get(order_by, :aggregation)

    {:ok, ordered_slugs} = Sanbase.Metric.slugs_order(metric, from, to, direction, aggregation)

    case slugs do
      :all ->
        ordered_slugs

      ^slugs when is_list(slugs) ->
        slugs_mapset = slugs |> MapSet.new()
        Enum.filter(ordered_slugs, &(&1 in slugs_mapset))
    end
  end
end