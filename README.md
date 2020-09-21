# JsonRfc

Pure-elixir implementations of IETF RFCs 6901 and 6902,
JSON Pointer and Patch respectively.

* https://github.com/lygaret/ex-jsonrfc
* https://hex.pm/packages/jsonrfc
* https://hexdocs.pm/jsonrfc

## RFC 6901, Json Pointer

[RFC 6901 - Json Pointer](https://tools.ietf.org/html/rfc6901) "defines
a string syntax for identifying a specific value within a JavaScript Object
Notation (JSON) document," which for our purposes are maps with string keys
or arrays.

```elixir
  iex> doc = %{"foo" => %{"bar" => "baz", "xyzzy" => ["a", "b", "c"]}}

  iex> JsonRfc.Pointer.fetch(doc, "/foo/bar")
  {:ok, "baz"}

  iex> JsonRfc.Pointer.fetch(doc, "/foo/xyzzy/1")
  {:ok, "b"}
```

## RFC 6902, Json Patch

[RFC 6902 - Json Patch](https://tools.ietf.org/html/rfc6902) "defines a
JSON document structure for expressing a sequence of operations to apply
to a JavaScript Object Notation (JSON) document."

This is represented here by a "operation maps" and a reducer over maps with
string keys and arrays.

```elixir
  iex> doc = %{"foo" => [], "byebye" => 5}
  iex> ops = [
  ...>   JsonRfc.Patch.add("/bar", 3),
  ...>   JsonRfc.Patch.replace("/foo", %{}),
  ...>   JsonRfc.Patch.remove("/byebye"),
  ...>   JsonRfc.Patch.move("/bar", "/foo/bar"),
  ...>   JsonRfc.Patch.copy("/foo", "/baz")
  ...> ]

  iex> JsonRfc.Patch.evaluate(doc, ops)
  {:ok, %{"foo" => %{"bar" => 3}, "baz" => %{"bar" => 3}}}
```

## Installation

```elixir
def deps do
  [
    {:jsonrfc, "~> 0.1.0"}
  ]
end
