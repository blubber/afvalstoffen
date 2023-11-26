defmodule Afvalstoffen.WebContent do

  defmodule NotFound do
    defexception message: "Address does not exist"
  end

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
    "#waste-kerstbomen" => :christmass_tree
  }

  def fetch(postal_code, number, addition \\ nil) do
    retrieve!(postal_code, number, addition)
    |> Floki.parse_document!()
    |> extract_events!()
  end

  defp extract_events!(html) do
    year = Date.utc_today().year

    @months
    |> Enum.with_index(1)
    |> Enum.map(fn {month, month_number} ->
      Floki.find(html, "##{month}-#{year} table")
      |> Enum.map(&extract_event!/1)
      |> Enum.map(fn {day, type} -> {Date.new!(year, month_number, day), type} end)
    end)
    |> Enum.reduce([], &Enum.concat/2)
    |> Enum.sort(fn({dt1, _}, {dt2, _}) -> Date.compare(dt1, dt2) == :lt end)
  end

  defp extract_event!(html) do
    [waste_class | _] = Floki.attribute(html, "a", "href")
    date_string = Floki.find(html, "p span.span-line-break") |> Floki.text()
    [_, day] = Regex.run(~r/^[^\s]+\s+(\d+)\s+.*$/, date_string)

    {String.to_integer(day), Map.fetch!(@waste_type_anchors, waste_class)}
  end

  defp retrieve!(postal_code, number, addition) do
    url = create_url(postal_code, number, addition)

    with %{status: 200} = response <- Req.get!(url) do
      response.body
    else
      _ -> raise NotFound
    end
  end

  defp create_url(postal_code, number, nil),
    do: "https://afvalstoffendienstkalender.nl/nl/" <> postal_code <> "/" <> number

  defp create_url(postal_code, number, addition),
    do: create_url(postal_code, number, nil) <> "/" <> addition
end
