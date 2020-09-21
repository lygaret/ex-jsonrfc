defmodule JsonRfcSpec do
  @moduledoc false

  use ESpec, async: true
  doctest JsonRfc, async: true

  describe "is_array_index/2" do
    import JsonRfc, only: [is_array_index: 2]

    assert is_array_index([0, 1, 2], 1)
    refute is_array_index([0, 1, 2], 10)
    refute is_array_index([0, 1, 2], -1)
    refute is_array_index([0, 1, 2], "whatup")
    refute is_array_index(:foo, 0)
  end

  describe "is_array_append/2" do
    import JsonRfc, only: [is_array_append: 2]

    assert is_array_append([0, 1, 2], "-")
    refute is_array_append([0, 1, 2], 0)
    refute is_array_append("hi", "-")
    refute is_array_append(:foo, 0)
  end

  describe "is_array/2" do
    import JsonRfc, only: [is_array: 2]

    assert is_array([0, 1, 2], "-")
    assert is_array([0, 1, 2], 0)
    refute is_array("hi", "-")
    refute is_array(:foo, 0)
  end
end
