defmodule Sanbase.Clickhouse.Github do
  @moduledoc ~s"""
  Uses ClickHouse to work with ETH transfers.
  Allows to filter on particular events in the queries. Development activity can
  be more clearly calculated by excluding events releated to commenting, issues, forks, stars, etc.
  """

  @type t :: %__MODULE__{
          datetime: %DateTime{},
          owner: String.t(),
          repo: String.t(),
          actor: String.t(),
          event: String.t()
        }

  use Ecto.Schema

  require Logger
  require Sanbase.ClickhouseRepo, as: ClickhouseRepo

  alias __MODULE__

  @non_dev_events [
    "IssueCommentEvent",
    "IssuesEvent",
    "ForkEvent",
    "CommitCommentEvent",
    "FollowEvent",
    "ForkEvent",
    "DownloadEvent",
    "WatchEvent"
  ]

  @table "github"

  @primary_key false
  @timestamps_opts updated_at: false
  schema @table do
    field(:datetime, :utc_datetime, source: :dt, primary_key: true)
    field(:repo, :string, primary_key: true)
    field(:event, :string, primary_key: true)
    field(:owner, :string)
    field(:actor, :string)
  end

  @spec changeset(any(), any()) :: no_return
  def changeset(_, _attrs \\ %{}) do
    raise "Cannot change github ClickHouse table!"
  end

  def total_dev_activity(organization, from, to) do
    {query, args} = total_dev_activity_query(organization, from, to)

    {:ok, [result]} = ClickhouseRepo.query_transform(query, args, fn [elem] -> elem end)
    {:ok, result |> String.to_integer()}
  end

  @doc ~s"""
  Get a timeseries with the pure development activity for a project.
  Pure development activity is all events excluding comments, issues, forks, stars, etc.
  """
  @spec dev_activity(String.t(), %DateTime{}, %DateTime{}, String.t()) ::
          {:ok, nil} | {:ok, list(t)} | {:error, String.t()}
  def dev_activity(nil, _, _, _), do: []

  def dev_activity(organization, from, to, interval, "None", _) do
    interval_sec = Sanbase.DateTimeUtils.compound_duration_to_seconds(interval)

    {:ok, result} =
      dev_activity_query(organization, from, to, interval_sec)
      |> datetime_activity_execute()
  end

  def dev_activity(organization, from, to, interval, "movingAverage", ma_base) do
    interval_sec = Sanbase.DateTimeUtils.compound_duration_to_seconds(interval)
    from = Timex.shift(from, seconds: -((ma_base - 1) * interval_sec))

    {:ok, result} =
      dev_activity_query(organization, from, to, interval_sec)
      |> datetime_activity_execute()

    sma(result, ma_base)
  end

  defp datetime_activity_execute({query, args}) do
    ClickhouseRepo.query_transform(query, args, fn [datetime, events_count] ->
      %{
        datetime: datetime |> Sanbase.DateTimeUtils.from_erl!(),
        activity: events_count |> String.to_integer()
      }
    end)
  end

  defp dev_activity_query(organization, from_datetime, to_datetime, interval) do
    from_datetime_unix = DateTime.to_unix(from_datetime)
    to_datetime_unix = DateTime.to_unix(to_datetime)
    span = div(to_datetime_unix - from_datetime_unix, interval)
    span = Enum.max([span, 1])

    query = """
    SELECT time, SUM(events) as events_count
      FROM (
        SELECT
          toDateTime(intDiv(toUInt32(?4 + number * ?1), ?1) * ?1) as time,
          0 AS events
        FROM numbers(?2)

        UNION ALL

        SELECT toDateTime(intDiv(toUInt32(dt), ?1) * ?1) as time, count(events) as events
          FROM (
            SELECT any(event) as events, dt
            FROM #{@table}
            PREWHERE owner = ?3
            AND dt >= toDateTime(?4)
            AND dt <= toDateTime(?5)
            AND event NOT in (?6)
            GROUP BY owner, dt
          )
          GROUP BY time
      )
      GROUP BY time
      ORDER BY time
    """

    args = [
      interval,
      span,
      organization,
      from_datetime_unix,
      to_datetime_unix,
      @non_dev_events
    ]

    {query, args}
  end

  defp total_dev_activity_query(owner, from, to) do
    query = """
    SELECT COUNT(*)
    FROM #{@table}
    PREWHERE owner = ?1
    AND dt >= toDateTime(?2)
    AND dt <= toDateTime(?3)
    """

    args = [
      owner,
      DateTime.to_unix(from),
      DateTime.to_unix(to)
    ]

    {query, args}
  end

  # Helper functions

  # Simple moving average of the github activity datapoints. Used to smooth the
  # noise created by the less amount of events created during the night and weekends
  defp sma(list, period) when is_list(list) and is_integer(period) and period > 0 do
    result =
      list
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn elems ->
        {datetime, activity} = average(elems)

        %{
          datetime: datetime,
          activity: Float.round(activity, 3)
        }
      end)

    {:ok, result}
  end

  defp average([]), do: nil

  defp average(l) when is_list(l) do
    values = Enum.map(l, fn %{activity: da} -> da end)
    %{datetime: datetime} = List.last(l)
    activity = Enum.sum(values) / length(values)

    {datetime, activity}
  end
end