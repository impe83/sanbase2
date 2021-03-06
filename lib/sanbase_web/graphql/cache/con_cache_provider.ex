defmodule SanbaseWeb.Graphql.ConCacheProvider do
  @moduledoc ~s"""
  Implements Sanbase.Cache.Behaviour for con_cache
  """
  @behaviour Sanbase.Cache.Behaviour

  @compile :inline_list_funcs
  @compile {:inline, get: 2, store: 3, get_or_store: 4, cache_item: 3}

  @max_cache_ttl 86_400

  @impl true
  def size(cache, :megabytes) do
    bytes_size = :ets.info(ConCache.ets(cache), :memory) * :erlang.system_info(:wordsize)
    (bytes_size / (1024 * 1024)) |> Float.round(2)
  end

  @impl true
  def clear_all(cache) do
    cache
    |> ConCache.ets()
    |> :ets.tab2list()
    |> Enum.each(fn {key, _} -> ConCache.delete(cache, key) end)
  end

  @impl true
  def get(cache, key) do
    case ConCache.get(cache, true_key(key)) do
      {:stored, value} -> value
      nil -> nil
    end
  end

  @impl true
  def store(cache, key, value) do
    case value do
      {:error, _} ->
        :ok

      {:nocache, _} ->
        Process.put(:has_nocache_field, true)
        :ok

      value ->
        cache_item(cache, key, {:stored, value})
    end
  end

  @impl true
  def get_or_store(cache, key, func, cache_modify_middleware) do
    # Do not include the TTL as part of the key name.
    true_key = true_key(key)

    {result, error_if_any} =
      case ConCache.get(cache, true_key) do
        {:stored, value} ->
          {value, nil}

        _ ->
          ConCache.isolated(cache, true_key, fn ->
            case ConCache.get(cache, true_key) do
              {:stored, value} ->
                {value, nil}

              _ ->
                case func.() do
                  {:error, _} = error ->
                    {nil, error}

                  {:middleware, _, _} = tuple ->
                    # Decides on its behalf whether or not to put the value in the cache
                    {cache_modify_middleware.(cache, key, tuple), nil}

                  {:nocache, {:ok, _result} = value} ->
                    Process.put(:do_not_cache_query, true)
                    {value, nil}

                  value ->
                    cache_item(cache, key, {:stored, value})
                    {value, nil}
                end
            end
          end)
      end

    if error_if_any != nil do
      error_if_any
    else
      result
    end
  end

  defp cache_item(cache, {key, ttl}, value) when is_integer(ttl) and ttl <= @max_cache_ttl do
    ConCache.put(cache, key, %ConCache.Item{value: value, ttl: :timer.seconds(ttl)})
  end

  defp cache_item(cache, key, value) do
    ConCache.put(cache, key, value)
  end

  defp true_key({key, ttl}) when is_integer(ttl) and ttl <= @max_cache_ttl, do: key
  defp true_key(key), do: key
end
