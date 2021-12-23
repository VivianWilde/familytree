defmodule FamilyTreeTest do
  use ExUnit.Case
  doctest FamilyTree

  test "setup" do
    Interaction.main()
  end
end
