defmodule Elixirator.Missions do
  @moduledoc "The three reference missions supplied in the challenge."

  @default_preset "apollo"

  @missions [
    {"apollo", %{name: "Apollo 11", mass: "28801", path: ~w(earth moon moon earth)}},
    {"mars", %{name: "Mars mission", mass: "14606", path: ~w(earth mars mars earth)}},
    {"passenger",
     %{name: "Passenger ship", mass: "75432", path: ~w(earth moon moon mars mars earth)}}
  ]

  def list, do: @missions

  def default_id, do: @default_preset

  def fetch(id) do
    case List.keyfind(@missions, id, 0) do
      {^id, mission} -> {:ok, mission}
      nil -> :error
    end
  end
end
