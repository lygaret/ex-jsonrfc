defmodule PatchSpec do
  @moduledoc false

  use ESpec, async: true
  doctest JsonRfc.Patch, async: true

  describe "evaluate: add" do
    import JsonRfc.Patch, only: [evaluate: 2, add: 2]

    let(:doc, do: %{"foo" => 5, "bar" => [1, 2, 3]})

    it "replaces keys" do
      result = evaluate(doc(), add("/foo", "hello"))
      expect(result) |> to(eq({:ok, %{"foo" => "hello", "bar" => [1, 2, 3]}}))
    end

    it "creates new keys" do
      result = evaluate(doc(), add("/baz", 5))
      expect(result) |> to(eq({:ok, %{"foo" => 5, "baz" => 5, "bar" => [1, 2, 3]}}))
    end

    it "right shifts array indices" do
      result = evaluate(doc(), add("/bar/1", "number"))
      expect(result) |> to(eq({:ok, %{"foo" => 5, "bar" => [1, "number", 2, 3]}}))
    end

    it "appends array indices" do
      result = evaluate(doc(), add("/bar/-", "number"))
      expect(result) |> to(eq({:ok, %{"foo" => 5, "bar" => [1, 2, 3, "number"]}}))
    end
  end

  describe "evaluate: replace" do
    import JsonRfc.Patch, only: [evaluate: 2, replace: 2]

    let(:doc, do: %{"foo" => 5, "bar" => [1, 2, 3]})

    it "replaces keys" do
      result = evaluate(doc(), replace("/foo", "hello"))
      expect(result) |> to(eq({:ok, %{"foo" => "hello", "bar" => [1, 2, 3]}}))
    end

    it "cannot create new keys" do
      result = evaluate(doc(), replace("/baz", 5))
      expect(result) |> to(be_error_result())
    end

    it "replaces array indices" do
      result = evaluate(doc(), replace("/bar/1", "number"))
      expect(result) |> to(eq({:ok, %{"foo" => 5, "bar" => [1, "number", 3]}}))
    end

    it "cannot append array indices" do
      result = evaluate(doc(), replace("/bar/-", "number"))
      expect(result) |> to(be_error_result())
    end
  end

  describe "evaluate: remove" do
    import JsonRfc.Patch, only: [evaluate: 2, remove: 1]

    let(:doc, do: %{"foo" => 5, "bar" => [1, 2, 3]})

    it "removes keys" do
      result = evaluate(doc(), remove("/bar"))
      expect(result) |> to(eq({:ok, %{"foo" => 5}}))
    end

    it "can't remove unknown keys" do
      result = evaluate(doc(), remove("/baz"))
      expect(result) |> to(be_error_result())
    end

    it "shifts right on array deletion" do
      result = evaluate(doc(), remove("/bar/1"))
      expect(result) |> to(eq({:ok, %{"foo" => 5, "bar" => [1, 3]}}))
    end

    it "cannot remove the append key" do
      result = evaluate(doc(), remove("/bar/-"))
      expect(result) |> to(be_error_result())
    end
  end
end
