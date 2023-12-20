defmodule AfvalstoffenWeb.ApiController do
  use AfvalstoffenWeb, :controller

  alias Ecto.Changeset

  alias Afvalstoffen.Calendar

  def index(conn, params) do
    changeset =
      %Calendar{}
      |> Calendar.changeset(params)

    with {:ok, calendar} <- Changeset.apply_action(changeset, :insert),
         events when is_list(events) <-
           AfvalstoffenWeb.WebContentCache.fetch(
             calendar.region,
             calendar.postal_code,
             calendar.number,
             calendar.addition
           ) do
      render(conn, :index, events: events)
    else
      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, changeset: changeset)

      :not_found ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Invalid address.")

      :error ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error, message: "Internal server error")
    end
  end
end
