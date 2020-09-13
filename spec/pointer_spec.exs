defmodule Json.PointerSpec do
  use ESpec, async: true
  doctest Json.Pointer, async: true

  describe "is_array_index/2" do
    import Json.Pointer, only: [is_array_index: 2]

    assert is_array_index([0,1,2], 1)
    refute is_array_index([0,1,2], 10)
    refute is_array_index([0,1,2], -1)
    refute is_array_index([0,1,2], "whatup")
    refute is_array_index(:foo, 0)
  end

  describe "is_array_append/2" do
    import Json.Pointer, only: [is_array_append: 2]

    assert is_array_append([0, 1, 2], "-")
    refute is_array_append([0,1,2], 0)
    refute is_array_append("hi", "-")
    refute is_array_append(:foo, 0)
  end

  describe "is_array/2" do
    import Json.Pointer, only: [is_array: 2]

    assert is_array([0, 1, 2], "-")
    assert is_array([0, 1, 2], 0)
    refute is_array("hi", "-")
    refute is_array(:foo, 0)
  end

  describe "transform/3" do
    import Json.Pointer, only: [transform: 3]

    it "fails with bad pointers in the arity-1 case" do
      expect transform(%{}, "bad/path", &(&1 + 1)) |> to(be_error_result())
    end

    it "fails when given bad paths" do
      doc = %{"foo" => [0, %{"cat" => [0, 1, 2]}, 2]}
      expect transform(doc, "/foo/1/cat/8", &(&1 + 1)) |> to(be_error_result())
    end

    it "handles errors in the arity-1 case" do
      doc = %{"foo" => [1]}
      expect transform(doc, "/foo/0", fn _ -> {:error, :a} end) |> to(eq {:error, :a})
    end
  end
end
