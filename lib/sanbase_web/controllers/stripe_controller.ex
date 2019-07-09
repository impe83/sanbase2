defmodule SanbaseWeb.StripeController do
  use SanbaseWeb, :controller

  require Logger

  alias Sanbase.Pricing.StripeEvent

  def webhook(conn, params) do
    stripe_event = conn.assigns[:stripe_event]
    Logger.info("Stripe event received: #{inspect(stripe_event)}")

    case StripeEvent.by_id(stripe_event["id"]) do
      nil ->
        StripeEvent.create(stripe_event)
        |> case do
          {:ok, _} ->
            StripeEvent.handle_event_async(stripe_event)
            success_response(conn)

          {:error, _} ->
            error_response(conn)
        end

      # duplicate event
      _ ->
        success_response(conn)
    end
  end

  defp success_response(conn) do
    conn
    |> resp(200, "OK")
    |> send_resp()
  end

  defp error_response(conn) do
    conn
    |> resp(500, "Error")
    |> send_resp()
  end
end
