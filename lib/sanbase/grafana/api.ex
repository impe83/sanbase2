defmodule Sanbase.GrafanaApi do
  require Sanbase.Utils.Config, as: Config
  require Mockery.Macro
  require Logger

  alias Sanbase.Auth.User

  @plan_team_map %{
    41 => "Sangraphs-Basic",
    42 => "Sangraphs-Pro",
    43 => "Sangraphs-Premium",
    44 => "Sangraphs-Basic",
    45 => "Sangraphs-Pro",
    46 => "Sangraphs-Premium"
  }

  def plan_team_map, do: @plan_team_map

  def get_user_by_email_or_username(%User{username: username, email: email}) do
    token = email || username
    request_path = "api/users/lookup?loginOrEmail=#{token}"

    Path.join(base_url(), request_path)
    |> http_client().get(headers())
    |> handle_response()
  end

  def create_user(%User{username: username, email: email}) do
    request_path = "api/admin/users"

    data =
      %{
        "name" => username || email,
        "email" => email || username,
        "login" => username || email,
        "password" => :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
      }
      |> Jason.encode!()

    Path.join(base_url(), request_path)
    |> http_client().post(data, headers())
    |> handle_response()
  end

  def add_subscribed_user_to_team(grafana_user_id, plan_id) do
    team_name = @plan_team_map[plan_id]

    with {:ok, %{"id" => team_id}} <- get_team_by_name(team_name),
         {:ok, team_members} <- get_team_members(team_id) do
      team_members
      |> Enum.find(fn %{"userId" => user_id} -> user_id == grafana_user_id end)
      |> case do
        nil ->
          remove_user_from_all_teams(grafana_user_id)
          add_user_to_team(grafana_user_id, team_id)

        _ ->
          {:ok, "User is already in this team"}
      end
    else
      error -> error
    end
  end

  # helpers
  defp remove_user_from_all_teams(user_id) do
    ["Sangraphs-Basic", "Sangraphs-Pro", "Sangraphs-Premium"]
    |> Enum.each(&remove_user_from_team(user_id, &1))
  end

  defp remove_user_from_team(user_id, team_name) do
    with {:ok, %{"id" => team_id}} <- get_team_by_name(team_name),
         {:ok, team_members} <- get_team_members(team_id) do
      team_members
      |> Enum.find(fn %{"userId" => uid} -> uid == user_id end)
      |> case do
        nil -> {:ok, "User is not in the #{team_name} team"}
        _ -> do_remove_user_from_team(user_id, team_id)
      end
    else
      {:error, error} ->
        Logger.error(
          "Error removing grafana user: #{user_id} from team: #{team_name}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp do_remove_user_from_team(user_id, team_id) do
    request_path = "api/teams/#{team_id}/members/#{user_id}"

    Path.join(base_url(), request_path)
    |> http_client().delete(headers())
    |> handle_response()
  end

  defp get_team_by_name(name) do
    request_path = "api/teams/search?name=#{name}"

    Path.join(base_url(), request_path)
    |> http_client().get(headers())
    |> handle_response()
    |> case do
      {:ok, %{"teams" => []}} ->
        {:error, "No such team: #{name}"}

      {:ok, teams} ->
        {:ok, Map.get(teams, "teams") |> hd()}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_team_members(team_id) do
    request_path = "api/teams/#{team_id}/members"

    Path.join(base_url(), request_path)
    |> http_client().get(headers())
    |> handle_response()
  end

  defp add_user_to_team(user_id, team_id) do
    request_path = "api/teams/#{team_id}/members"
    data = %{"userId" => user_id} |> Jason.encode!()

    Path.join(base_url(), request_path)
    |> http_client().post(data, headers())
    |> handle_response()
  end

  defp http_client(), do: HTTPoison

  defp base_url, do: Config.get(:grafana_base_url)

  defp basic_auth_header() do
    credentials =
      (Config.get(:grafana_user) <> ":" <> Config.get(:grafana_pass))
      |> Base.encode64()

    {"Authorization", "Basic #{credentials}"}
  end

  defp headers() do
    [
      {"Content-Type", "application/json"},
      basic_auth_header()
    ]
  end

  defp handle_response(response) do
    response
    |> case do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 200..299 ->
        {:ok, body |> Jason.decode!()}

      other ->
        Logger.error("Error response from grafana API: #{inspect(other)}")
        {:error, "Error response from grafana API"}
    end
  end
end
