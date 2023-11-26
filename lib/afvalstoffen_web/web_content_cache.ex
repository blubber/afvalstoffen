defmodule AfvalstoffenWeb.WebContentCache do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def fetch(postal_code, number, addition) do
    GenServer.call(__MODULE__, {:fetch, postal_code, number, addition}, 60_000)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:fetch, postal_code, number, addition}, _from, cache) do
    key = {postal_code, number, addition}
    now = DateTime.utc_now()

    with {ttl, events} <- Map.get(cache, key),
         :gt <- DateTime.compare(ttl, now) do
      {:reply, events, cache}
    else
      _ ->
        {ttl, events} =
          try do
            {86399, Afvalstoffen.WebContent.fetch(postal_code, number, addition)}
          rescue
            Afvalstoffen.WebContent.NotFound -> {3600, :not_found}
            _ -> {60, :error}
          end

        timeout = DateTime.add(now, ttl)
        {:reply, events, Map.put(cache, key, {timeout, events})}
    end
  end
end
