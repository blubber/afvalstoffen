defmodule AfvalstoffenWeb.ApiController do
  use AfvalstoffenWeb, :controller

  alias Ecto.Changeset

  alias Afvalstoffen.Address

  def index(conn, params) do
    changeset =
      %Address{}
      |> Address.changeset(params)

    with {:ok, address} <- Changeset.apply_action(changeset, :insert),
         events when is_list(events) <-
           AfvalstoffenWeb.WebContentCache.fetch(
             address.postal_code,
             address.number,
             address.addition
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
