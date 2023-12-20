defmodule Afvalstoffen.Calendar do
  use Ecto.Schema

  import Ecto.Changeset
  alias Ecto.Changeset

  alias Afvalstoffen.Address

  schema "calendar" do
    field(:postal_code)
    field(:number)
    field(:addition, :string, default: "")
    field(:label_non_recyclable, :string, default: "🚮 Restafval")
    field(:label_organic, :string, default: "🍌 Groente, Fruit en Tuinafval")
    field(:label_paper, :string, default: "💵 Papier")
    field(:label_packaging, :string, default: "🎁 Verpakkingen")
    field(:label_christmass_tree, :string, default: "🎄 Kerstbomen")
    field(:event_start, :time, default: ~T[07:00:00])
    field(:event_end, :time, default: ~T[09:00:00])
    field(:alarm1, :integer)
    field(:alarm2, :integer)
  end

  def changeset(parameters, params \\ %{}) do
    parameters
    |> cast(params, [
      :postal_code,
      :number,
      :addition,
      :label_non_recyclable,
      :label_organic,
      :label_paper,
      :label_packaging,
      :label_christmass_tree,
      :event_start,
      :event_end,
      :alarm1,
      :alarm2
    ])
    |> update_change(:label_non_recyclable, &String.trim/1)
    |> update_change(:label_organic, &String.trim/1)
    |> update_change(:label_paper, &String.trim/1)
    |> update_change(:label_packaging, &String.trim/1)
    |> update_change(:label_christmass_trees, &String.trim/1)
    |> Address.validate_address()
    |> validate_length(:label_non_recyclable, min: 2, max: 50)
    |> validate_length(:label_organic, min: 2, max: 50)
    |> validate_length(:label_packaging, min: 2, max: 50)
    |> validate_length(:label_paper, min: 2, max: 50)
    |> validate_length(:label_christmass_tree, min: 2, max: 50)
    |> maybe_validate_alarm(:alarm1)
    |> maybe_validate_alarm(:alarm2)
  end

  def to_ical(calendar, events) do
    ical_events =
      events
      |> Enum.map(fn {date, type} ->
        create_event(calendar, date, type)
      end)

    serialized_events = Enum.join(ical_events, "")

    """
    BEGIN:VCALENDAR
    CALSCALE:GREGORIAN
    VERSION:2.0
    PRODID:-//Elixir ICalendar//Elixir ICalendar//EN
    X-WR-CALNAME:Afvalstoffen
    #{serialized_events}END:VCALENDAR
    """
    |> String.split("\n")
    |> Enum.join("\r\n")
  end

  defp maybe_validate_alarm(changeset, field) do
    alarm = get_change(changeset, field)

    if alarm do
      changeset
      |> validate_number(field, greater_than_or_equal_to: 0, less_than: 24 * 7)
    else
      changeset
    end
  end

  defp create_event(calendar, date, type) do
    summary =
      case type do
        :non_recyclable -> calendar.label_non_recyclable
        :organic -> calendar.label_organic
        :paper -> calendar.label_paper
        :packaging -> calendar.label_packaging
        :christmass_tree -> calendar.label_christmass_tree
        type -> "Onbekend: #{type}"
      end

    uid = :crypto.hash(:sha, summary <> Date.to_string(date)) |> Base.encode16()

    dtstart =
      DateTime.new!(date, calendar.event_start, "Europe/Amsterdam")
      |> Timex.Timezone.convert("UTC")

    dtend =
      DateTime.new!(date, calendar.event_end, "Europe/Amsterdam")
      |> Timex.Timezone.convert("UTC")

    {:ok, now} = DateTime.now("UTC")

    alarms =
      [calendar.alarm1, calendar.alarm2]
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(fn offset -> create_alarm(offset, summary) end)
      |> Enum.join("")

    """
    BEGIN:VEVENT
    DTSTAMP:#{ICalendar.Value.to_ics(now)}Z
    DTSTART:#{ICalendar.Value.to_ics(dtstart)}Z
    DTEND:#{ICalendar.Value.to_ics(dtend)}Z
    SUMMARY:#{summary}
    UID:#{uid}
    #{alarms}END:VEVENT
    """
  end

  def encode_query(%Changeset{} = changeset) do
    %{
      "postal_code" => get_field(changeset, :postal_code),
      "number" => get_field(changeset, :number),
      "addition" => get_field(changeset, :addition),
      "label_non_recyclable" => get_field(changeset, :label_non_recyclable),
      "label_organic" => get_field(changeset, :label_organic),
      "label_packaging" => get_field(changeset, :label_packaging),
      "label_paper" => get_field(changeset, :label_paper),
      "label_christmass_tree" => get_field(changeset, :label_christmass_tree),
      "alarm1" => get_field(changeset, :alarm1),
      "alarm2" => get_field(changeset, :alarm2)
    }
    |> URI.encode_query()
  end

  def encode_query(%__MODULE__{} = calendar) do
    calendar
    |> Map.from_struct()
    |> URI.encode_query()
  end

  defp create_alarm(offset, summary) do
    """
    BEGIN:VALARM
    TRIGGER:-PT#{offset}H
    ACTION:DISPLAY
    DESCRIPTION:#{summary}
    END:VALARM
    """
  end
end
