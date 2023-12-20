defmodule Afvalstoffen.Source.Twentemilieu do
  @company_code "8d97bb56-5afd-4cbc-a651-b4f7314264b4"
  @pickup_types %{
    0 => :non_recyclable,
    1 => :organic,
    2 => :paper,
    10 => :packaging
  }

  def fetch(postal_code, number, addition \\ "") do
    postal_code =
      postal_code
      |> String.replace(" ", "")
      |> String.upcase()

    with {:ok, address_id} <- address_id(postal_code, number, addition),
         {:ok, data} <- get_calendar(address_id) do
      extract_events(data)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :error}
    end
  end

  defp address_id(postal_code, number, addition) do
    with {:ok, %{status: 200, body: body}} <-
           Req.post(
             "https://twentemilieuapi.ximmio.com/api/FetchAdress",
             json: %{
               companyCode: @company_code,
               postCode: postal_code,
               houseNumber: number,
               houseLetter: addition
             },
             headers: %{
               "Content-Type" => "application/json",
               Accept: "application/json"
             }
           ),
         {:ok, data_list} when is_list(data_list) <- Map.fetch(body, "dataList"),
         [data | _] <- data_list,
         {:ok, unique_id} <- Map.fetch(data, "UniqueId") do
      {:ok, unique_id}
    else
      _ -> {:error, :not_found}
    end
  end

  defp get_calendar(unique_id) do
    %{year: year} = Date.utc_today()
    get_calendar(unique_id, year)
  end

  defp get_calendar(unique_id, year) do
    case Req.post(
           "https://twentemilieuapi.ximmio.com/api/GetCalendar",
           json: %{
             companyCode: @company_code,
             uniqueAddressID: unique_id,
             startDate: "#{year}-01-01",
             endDate: "#{year + 1}-12-31"
           },
           headers: %{
             "Content-Type" => "application/json",
             "Accept" => "application/json",
             "User-Agent" => "afvalstoffen.isogram.nl/42"
           }
         ) do
      {:ok, %{status: 200, body: %{"status" => true, "dataList" => data}}} ->
        {:ok, data}

      _ ->
        {:error, :error}
    end
  end

  defp extract_events(data) when is_list(data) do
    {:ok,
     Enum.map(data, &extract_events/1)
     |> Enum.reduce([], &(&1 ++ &2))
     |> Enum.sort(fn {dt1, _}, {dt2, _} -> Date.compare(dt1, dt2) == :lt end)}
  end

  defp extract_events(%{
         "pickupDates" => pickup_dates,
         "pickupType" => pickup_type,
         "_pickupTypeText" => pickup_type_text
       }) do
    type = Map.get(@pickup_types, pickup_type, pickup_type_text)

    pickup_dates
    |> Enum.map(fn date ->
      {:ok, timestamp, _} = DateTime.from_iso8601("#{date}Z")
      {DateTime.to_date(timestamp), type}
    end)
  end
end
