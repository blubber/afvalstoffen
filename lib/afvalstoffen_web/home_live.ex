defmodule AfvalstoffenWeb.HomeLive do
  use AfvalstoffenWeb, :live_view

  alias Ecto.Changeset
  alias Phoenix.LiveView.JS

  alias Afvalstoffen.Calendar

  def render(assigns) do
    changeset = assigns.changeset

    query =
      %{
        "postal_code" => Changeset.get_field(changeset, :postal_code),
        "number" => Changeset.get_field(changeset, :number),
        "addition" => Changeset.get_field(changeset, :addition),
        "label_non_recyclable" => Changeset.get_field(changeset, :label_non_recyclable),
        "label_organic" => Changeset.get_field(changeset, :label_organic),
        "label_packaging" => Changeset.get_field(changeset, :label_packaging),
        "label_paper" => Changeset.get_field(changeset, :label_paper),
        "label_christmass_tree" => Changeset.get_field(changeset, :label_christmass_tree),
        "alarm1" => Changeset.get_field(changeset, :alarm1),
        "alarm2" => Changeset.get_field(changeset, :alarm2)
      }
      |> URI.encode_query()

    assigns =
      assigns
      |> assign_example_calendar()
      |> assign_address()
      |> assign(query: query)

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
              <.input field={@form[:postal_code]} type="text" label="Postcode" />
              <.input field={@form[:number]} type="text" label="Huisnummer" />
              <.input field={@form[:addition]} type="text" label="Toevoeging" />

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

          <div class="mt-4">
            <a
              href={~p"/afvalstoffen.ics" <> "?#{query}"}
              class="block w-full flex justify-center rounded-md bg-blue-500 text-white leading-10 font-bold hover:bg-blue-400 cursor-pointer"
            >
              Open in kalender
            </a>
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

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"calendar" => calendar}, socket) do
    changeset =
      Calendar.changeset(%Calendar{}, calendar)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
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

  defp assign_address(assigns) do
    postal_code = Changeset.get_field(assigns.changeset, :postal_code)
    number = Changeset.get_field(assigns.changeset, :number)
    addition = Changeset.get_field(assigns.changeset, :addition)

    number_part = if number != "" and addition != "", do: "#{number}-#{addition}", else: number

    assign(
      assigns,
      address: [postal_code, number_part] |> Enum.filter(&(&1 != "")) |> Enum.join(", ")
    )
  end
end
