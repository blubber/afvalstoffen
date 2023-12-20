defmodule AfvalstoffenWeb.CalendarController do
  use AfvalstoffenWeb, :controller

  def index(conn, params) do
    changeset = %Afvalstoffen.Calendar{} |> Afvalstoffen.Calendar.changeset(params)

    with {:ok, calendar} <- Ecto.Changeset.apply_action(changeset, :validatee) do
      events =
        AfvalstoffenWeb.WebContentCache.fetch(
          calendar.region,
          calendar.postal_code,
          calendar.number,
          calendar.addition
        )

      t =
        calendar |> Afvalstoffen.Calendar.to_ical(events)

      conn
      |> put_resp_content_type("text/calendar")
      |> text(t)
    else
      {:error, changeset} ->
        IO.inspect(changeset)
        redirect(conn, to: ~p"/")

      _ ->
        redirect(conn, to: ~p"/")
    end
  end
end
