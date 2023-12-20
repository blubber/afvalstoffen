defmodule AfvalstoffenWeb.WebContentCache do
  use GenServer

  alias Afvalstoffen.Source.Afvalstoffendienst
  alias Afvalstoffen.Source.Twentemilieu

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def fetch(region, postal_code, number, addition) do
    GenServer.call(__MODULE__, {:fetch, region, postal_code, number, addition}, 60_000)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:fetch, :brabant, postal_code, number, addition}, _from, cache) do
    key = {postal_code, number, addition}
    now = DateTime.utc_now()

    with {ttl, events} <- Map.get(cache, key),
         :gt <- DateTime.compare(ttl, now) do
      {:reply, events, cache}
    else
      _ ->
        {ttl, events} =
          case Afvalstoffendienst.fetch(postal_code, number, addition) do
            {:ok, events} ->
              {86499, events}

            {:error, :not_found} ->
              {3600, :not_found}

            {:error, _} ->
              {60, :error}
          end

        timeout = DateTime.add(now, ttl)
        {:reply, events, Map.put(cache, key, {timeout, events})}
    end
  end

  def handle_call({:fetch, :twente, postal_code, number, addition}, _from, cache) do
    key = {postal_code, number, addition}
    now = DateTime.utc_now()

    with {ttl, events} <- Map.get(cache, key),
         :gt <- DateTime.compare(ttl, now) do
      {:reply, events, cache}
    else
      _ ->
        {ttl, events} =
          case Twentemilieu.fetch(postal_code, number, addition) do
            {:ok, events} ->
              {86499, events}

            {:error, :not_found} ->
              {3600, :not_found}

            {:error, _} ->
              {60, :error}
          end

        timeout = DateTime.add(now, ttl)
        {:reply, events, Map.put(cache, key, {timeout, events})}
    end
  end
end
