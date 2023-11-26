defmodule Afvalstoffen.Address do
  use Ecto.Schema

  alias Ecto.Changeset

  schema "address" do
    field(:postal_code)
    field(:number)
    field(:addition, :string, default: "")
  end

  def changeset(address, params \\ %{}) do
    address
    |> Changeset.cast(params, [:postal_code, :number, :addition])
    |> validate_address()
  end

  def validate_address(changeset) do
    changeset
    |> Changeset.update_change(:postal_code, &String.trim/1)
    |> Changeset.update_change(:number, &String.trim/1)
    |> Changeset.update_change(:addition, &String.trim/1)
    |> Changeset.validate_required([:postal_code, :number])
    |> Changeset.validate_format(:postal_code, ~r/^\d{4}\s?[a-zA-Z]{2}/)
    |> Changeset.validate_length(:number, min: 1, max: 10)
  end
end
