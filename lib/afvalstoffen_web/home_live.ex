defmodule AfvalstoffenWeb.HomeLive do
  use AfvalstoffenWeb, :live_view

  alias Ecto.Changeset
  alias Phoenix.LiveView.AsyncResult

  alias Afvalstoffen.Calendar

  def render(assigns) do
    changeset = assigns.changeset
    query = Calendar.encode_query(changeset)

    assigns =
      assigns
      |> assign_example_calendar()
      |> assign(link: ~p"/afvalstoffen.ics" <> "?#{query}")

    ~H"""
    <div class="w-full max-w-screen-sm mx-auto">
      <div>
        <h1 class="text-xl sm:text-2xl font-semibold text-netural-800 dark:text-neutral-200">
          Afvalstoffen Kalender
        </h1>
        <p class="mt-4">
          Vul het onderstaande formulier in om een kalender te genereren met alle afval-ophaalmomenten
          voor jouw adres. Klik vervolgens op de "Open in kalender" knop om de kalender te importeren in
          je kalender app.
        </p>
      </div>
      <div class="grid grid-cols-1  md:grid-cols-2 gap-4 sm:gap-8 mt-6">
        <div>
          <.simple_form for={@form} id="form" phx-change="validate">
            <div class="mt-4 flex flex-col gap-2">
              <.input
                field={@form[:region]}
                type="select"
                label="Regio"
                options={[{"Brabant", :brabant}, {"Twente", :twente}]}
              />
              <.input field={@form[:postal_code]} type="text" label="Postcode" phx-debounce="600" />
              <.input field={@form[:number]} type="text" label="Huisnummer" phx-debounce=600 />
              <.input field={@form[:addition]} type="text" label="Toevoeging" phx-debounce="600" />

              <.input field={@form[:label_non_recyclable]} type="text" label="Restafval" />
              <.input field={@form[:label_organic]} type="text" label="GFT" />
              <.input field={@form[:label_paper]} type="text" label="Papier" />
              <.input field={@form[:label_packaging]} type="text" label="Verpakkingen" />
              <.input field={@form[:label_christmass_tree]} type="text" label="Kerstbomen" />
              <.input field={@form[:event_start]} type="time" label="Item begint om" />
              <.input field={@form[:event_end]} type="time" label="Item eindigt om" />

              <div class="text-sm text-neutral-800 dark:text-neutral-200">
                De notificatietijden zijn het aantal uur <em>voor</em> de start van het agendaitem
                waarop je een notificatie wilt. Beiden zijn optioneel.
              </div>
              <.input field={@form[:alarm1]} type="number" step="1" label="Notificatie 1" />
              <.input field={@form[:alarm2]} type="number" step="1" label="Notificatie 2" />
            </div>
          </.simple_form>
        </div>

        <div>
          <div class="flex flex-cols">
            <div class="flex-0">
              <div
                :for={h <- @interval}
                style={"height: #{@pixels_per_hour}px; line-height: #{@pixels_per_hour}px"}
                class="text-xs leading-8 pr-1 text-neutral-700 dark:text-neutral-300"
              >
                <%= format_time(h) %>
              </div>
            </div>
            <div class="flex-1">
              <div
                style={"margin-top: #{@event_offset}px; height: #{@event_height}px;"}
                class="bg-blue-100 dark:bg-blue-900 text-blue-900 dark:text-blue-100 border-l-4 border-blue-500 p-1 pl-2"
              >
                <%= @label %>
              </div>
              <div class="h-9"></div>
            </div>
          </div>

          <div :if={!@address_valid} class="mt-4">
            <.error>
              Het opgegeven adres is niet geldig.
            </.error>
          </div>

          <div :if={@address_valid} class="mt-4 flex flex-col gap-4">
            <.async_result :let={_events} assign={@events}>
              <:loading>Bezig met laden</:loading>
              <:failed :let={_reason}>Onbekend adres</:failed>
              <div>
                <a
                  href={@link}
                  class="block w-full flex justify-center rounded-md bg-blue-500 text-white leading-10 font-bold hover:bg-blue-400 cursor-pointer"
                >
                  Open in kalender
                </a>
              </div>
              <div class="text-sm text-neutral-700 dark:text-neutral-300">
                Als het openen niet werkt kun je de link ook kopieren en in je agenda
                toevoegen als subscription.
              </div>
            </.async_result>
          </div>
        </div>
      </div>

      <div class="mt-12">
        <h1 class="text-base sm:text-lg font-semibold text-netural-800 dark:text-neutral-200">
          Privacy
        </h1>
        <p class="mt-3 text-sm">
          Als je deze website gebruikt om een kalender te genereren worden je postcode, huisnummer
          en toeving naar
          <a href="https://afvalstoffendienstkalender.nl" target="_blank">
            afvalstoffendienstkalender.nl
          </a>
          gestuurd om de gegevens op te halen. Alle correct ingevulde postcode, huisnummer en toevoeging
          combinaties worden tot 24 uur opgeslagen in het geheugen van de server als cache. Je IP-adres wordt
          nooit opgeslagen.
        </p>
      </div>
      <div class="mt-10 flex justify-center text-neutral-600 dark:text-neutral-400">
        <div>
          <a href="mailto:afvalstoffen@isogram.nl">
            <span class="sr-only">Neem contact op via: afvalstoffen@isogram.nl</span>
            <.icon name="hero-envelope" class="w-8 h-8" />
          </a>
        </div>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    params =
      params
      |> Map.put_new("alarm1", "0")
      |> Map.put_new("alarm2", "12")

    changeset = %Calendar{} |> Calendar.changeset(params)

    address_valid =
      [:postal_code, :number, :addition]
      |> Enum.map(&(!Keyword.has_key?(changeset.errors, &1)))
      |> Enum.all?()

    {
      :ok,
      socket
      |> assign_form(changeset)
      |> maybe_async_assign_events(address_valid)
      |> assign(address_valid: address_valid)
    }
  end

  def handle_event("validate", %{"calendar" => calendar}, socket) do
    changeset =
      Calendar.changeset(%Calendar{}, calendar)
      |> Map.put(:action, :validate)

    address_valid =
      [:postal_code, :number, :addition]
      |> Enum.map(&(!Keyword.has_key?(changeset.errors, &1)))
      |> Enum.all?()

    {
      :noreply,
      socket
      |> assign_form(changeset)
      |> maybe_async_assign_events(address_valid)
      |> assign(address_valid: address_valid)
    }
  end

  defp assign_form(socket, changeset) do
    socket
    |> assign(changeset: changeset)
    |> assign(form: to_form(changeset))
  end

  defp format_time(time) do
    hour =
      time.hour
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    minute =
      time.minute
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    hour |> String.pad_leading(2, "0")

    "#{hour}:#{minute}"
  end

  defp assign_example_calendar(assigns) do
    changeset = Map.get(assigns, :changeset)

    {event_start, event_end} =
      with %Time{} = event_start <- Changeset.get_field(changeset, :event_start),
           %Time{} = event_end <- Changeset.get_field(changeset, :event_end),
           :lt <- Time.compare(event_start, event_end) do
        {event_start, event_end}
      else
        _ -> {~T[07:00:00], ~T[09:00:00]}
      end

    {event_start_offset, _} = Time.to_seconds_after_midnight(event_start)
    {event_end_offset, _} = Time.to_seconds_after_midnight(event_end)

    interval_start =
      Time.from_seconds_after_midnight(event_start_offset - rem(event_start_offset - 1, 3600) - 1)

    interval_end =
      Time.from_seconds_after_midnight(event_end_offset + 3600 - rem(event_end_offset, 3600))

    span = Time.diff(interval_end, interval_start, :hour)

    pixels_per_hour = max(24, min(48, round(400 / span)))

    event_offset =
      pixels_per_hour * (Time.diff(event_start, interval_start) / 3600) + pixels_per_hour / 2

    event_height = pixels_per_hour * Time.diff(event_end, event_start) / 3600

    interval = 0..span |> Enum.map(fn i -> Time.add(interval_start, i, :hour) end)

    assigns
    |> assign(event_start: event_start, event_end: event_end)
    |> assign(pixels_per_hour: pixels_per_hour)
    |> assign(event_offset: event_offset)
    |> assign(event_height: event_height)
    |> assign(interval: interval)
    |> assign(label: assigns.form[:label_non_recyclable].value)
  end

  defp maybe_async_assign_events(socket, true) do
    changeset = socket.assigns.changeset

    socket
    |> assign(:events, AsyncResult.loading())
    |> start_async(
      :events,
      fn -> fetch_events(changeset) end
    )
  end

  defp maybe_async_assign_events(socket, false),
    do: assign(socket, :events, AsyncResult.loading())

  defp fetch_events(changeset) do
    AfvalstoffenWeb.WebContentCache.fetch(
      Changeset.get_field(changeset, :region),
      Changeset.get_field(changeset, :postal_code),
      Changeset.get_field(changeset, :number),
      Changeset.get_field(changeset, :addition)
    )
  end

  def handle_async(:events, {:ok, :not_found}, socket) do
    {
      :noreply,
      assign(
        socket,
        :events,
        AsyncResult.loading()
        |> AsyncResult.failed({:error, :reason})
      )
    }
  end

  def handle_async(:events, {:ok, events}, socket) do
    {
      :noreply,
      assign(
        socket,
        :events,
        AsyncResult.loading()
        |> AsyncResult.ok(events)
      )
    }
  end
end
