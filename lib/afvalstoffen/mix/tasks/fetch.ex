defmodule Mix.Tasks.Fetch do
  use Mix.Task

  alias Afvalstoffen.WebContent

  def run([postal_code, number]), do: run([postal_code, number, nil])

  def run([postal_code, number, addition]) do
    Mix.Task.run("app.start")

    r = WebContent.fetch(postal_code, number, addition)
    IO.inspect(r)
  end
end
