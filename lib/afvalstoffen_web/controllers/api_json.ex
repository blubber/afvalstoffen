defmodule AfvalstoffenWeb.ApiJSON do
  def index(%{events: events}) do
    Enum.map(events, fn {dt, type} ->
      %{"day" => Date.to_string(dt), "type" => Atom.to_string(type)}
    end)
  end

  def error(%{changeset: changeset}) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def error(%{message: message}) do
    %{"error" => message}
  end
end
