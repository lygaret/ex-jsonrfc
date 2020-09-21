defmodule PointerSpec do
  @moduledoc false

  use ESpec, async: true
  doctest JsonRfc.Pointer, async: true

  describe "parse/1" do
    import JsonRfc.Pointer, only: [parse: 1]

    describe "integer handling" do
      it "parses numbers as integers" do
        expect(parse("/8") |> to(eq({:ok, [8]})))
      end

      it "parses numbers only if they are the full key" do
        expect(parse("/8bar") |> to(eq({:ok, ["8bar"]})))
      end

      # the RFC disallows leading zeros as array indices, but doesn't
      # at all restrict the values that might be a key for an object;
      # since we're parsing the pointer outside of the context of a document
      # wherein we could determine if a leading zero is in an array context,
      # we have to allow it, since it may be an object key.

      # Luckily, since Json (per RFC 7159) _also_ disallows leading zeros
      # to be numbers, we can assume that a leading zero in a path *should*
      # be a string key into an object.

      it "parses leading zeros as strings, per RFC" do
        expect(parse("/0") |> to(eq({:ok, [0]})))
        expect(parse("/03") |> to(eq({:ok, ["03"]})))
      end
    end

    describe "rfc test cases" do
      it "handles the empty string, per RFC" do
        expect(parse("") |> to(eq({:ok, []})))
      end

      it "handles '/' as a pointer to a blank string key, per RFC" do
        expect(parse("/") |> to(eq({:ok, [""]})))
      end

      it "parses ~0 and ~1, per RFC" do
        expect(parse("/a~1b") |> to(eq({:ok, ["a/b"]})))
        expect(parse("/~10") |> to(eq({:ok, ["/0"]})))
        expect(parse("/~01") |> to(eq({:ok, ["~1"]})))
        expect(parse("/~10/~01/~0/~1") |> to(eq({:ok, ["/0", "~1", "~", "/"]})))
      end

      it "handles escapes correctly" do
        expect(parse(~S(/i\\j)) |> to(eq({:ok, [~S(i\j)]})))
        expect(parse(~S(/i\"j)) |> to(eq({:ok, [~S(i"j)]})))

        # TODO: rfc specifies that control chars can also be escaped
      end
    end
  end

  describe "fetch/2" do
    import JsonRfc.Pointer, only: [fetch: 2]

    let(:document) do
      %{
        "foo" => "bar",
        "baz" => [1, %{"42" => "towel"}, 3]
      }
    end

    it "handles integer keys in context" do
      expect(fetch(document(), "/baz/2") |> to(eq({:ok, 3})))
      expect(fetch(document(), "/baz/1/42")) |> to(eq({:ok, "towel"}))
    end

    describe "graceful failure" do
      it "errors out with missing array index" do
        expect(fetch(document(), "/baz/10")) |> to(eq({:error, :invalid_path}))
        expect(fetch(document(), "/baz/-")) |> to(eq({:error, :invalid_path}))
        expect(fetch(document(), "/baz/hi")) |> to(eq({:error, :invalid_path}))
      end

      it "errors out with missing map keys" do
        expect(fetch(document(), "/howdy")) |> to(eq({:error, :invalid_path}))
      end
    end
  end

  describe "transform/3" do
    import JsonRfc.Pointer, only: [transform: 3]

    let(:document) do
      %{ "foo" => [1, 2, 3] }
    end

    it "fails when given bad paths" do
      expect(transform(document(), "/foo/1/cat/8", &(&1 + 1)) |> to(be_error_result()))
    end

    describe "callback return values" do
      it "may return value directly, in the arity-1 case" do
        expect(transform(document(), "/foo/0", &(&1 + 1)))
        |> to(eq {:ok, %{"foo" => [2, 2, 3]}})
      end

      it "may return {:ok, result}, in the arity-1 case" do
        expect(transform(document(), "/foo/0", fn i -> {:ok, i + 1} end))
        |> to(eq {:ok, %{"foo" => [2, 2, 3]}})
      end

      it "may return value directly, in the arity-2 case" do
        expect(transform(document(), "/foo/0", &List.replace_at(&1, &2, "hello")))
        |> to(eq {:ok, %{"foo" => ["hello", 2, 3]}})
      end

      it "may return {:ok, result}, in the arity-2 case" do
        expect(transform(document(), "/foo/0", fn a, i -> {:ok, Enum.reverse(a) ++ [i]} end))
        |> to(eq {:ok, %{"foo" => [3, 2, 1, 0]}})
      end

      it "may return {:error, whatever} in the arity-1 case" do
        expect(transform(document(), "/foo/0", fn _ -> {:error, :wat} end))
        |> to(eq {:error, :wat})
      end

      it "may return {:error, whatever} in the arity-2 case" do
        expect(transform(document(), "/foo/0", fn _, _ -> {:error, :wat} end))
        |> to(eq {:error, :wat})
      end
    end
  end
end
