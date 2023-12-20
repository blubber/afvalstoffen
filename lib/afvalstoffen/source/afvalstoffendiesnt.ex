defmodule Afvalstoffen.Source.Afvalstoffendienst do
  @months [
    "january",
    "february",
    "march",
    "april",
    "may",
    "june",
    "july",
    "august",
    "september",
    "october",
    "november",
    "december"
  ]
  @waste_type_anchors %{
    "#waste-restafval" => :non_recyclable,
    "#waste-papier" => :paper,
    "#waste-gft" => :organic,
    "#waste-kerstbomen" => :christmass_tree,
    "#waste-pd" => :packaging,
  }

  def fetch(postal_code, number, addition \\ nil) do
    with {:ok, body} <- retrieve(postal_code, number, addition),
         {:ok, document} <- Floki.parse_document(body) do
      {:ok, extract_events(document)}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :error}
    end
  end

  defp extract_events(html) do
    year = Date.utc_today().year

    extract_events(html, year)
    |> Enum.concat(extract_events(html, year + 1))
  end

  defp extract_events(html, year) do
    @months
    |> Enum.with_index(1)
    |> Enum.map(fn {month, month_number} ->
      Floki.find(html, "##{month}-#{year} table")
      |> Enum.map(&extract_event/1)
      |> Enum.map(fn {day, type} -> {Date.new!(year, month_number, day), type} end)
    end)
    |> Enum.reduce([], &Enum.concat/2)
    |> Enum.sort(fn {dt1, _}, {dt2, _} -> Date.compare(dt1, dt2) == :lt end)
  end

  defp extract_event(html) do
    [waste_class | _] = Floki.attribute(html, "a", "href")
    date_string = Floki.find(html, "p span.span-line-break") |> Floki.text()
    [_, day] = Regex.run(~r/^[^\s]+\s+(\d+)\s+.*$/, date_string)

    {String.to_integer(day), Map.get(@waste_type_anchors, waste_class, waste_class)}
  end

  defp retrieve(postal_code, number, addition) do
    url = create_url(postal_code, number, addition)

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      _ ->
        {:error, :error}
    end
  end

  defp create_url(postal_code, number, nil),
    do: "https://afvalstoffendienstkalender.nl/nl/" <> postal_code <> "/" <> number

  defp create_url(postal_code, number, addition),
    do: create_url(postal_code, number, nil) <> "/" <> addition
end
