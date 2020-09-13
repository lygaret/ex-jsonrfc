defmodule Json.Pointer do
  alias __MODULE__

  @moduledoc ~s"""
  Fetch and transform data in Maps by evaluating JSON pointers
  """

  @doc """
  Returns true if `array` is a list, `index` is an integer, and `index` isn't out of bounds.
  """
  def is_array_index(array, index) do
    is_list(array) and is_integer(index) and index >= 0 and length(array) > index
  end

  @doc """
  Returns true if `array` is a list, and `index` is the special 'append' indicator.
  """
  def is_array_append(array, index) do
    is_list(array) and index == "-"
  end

  @doc """
  Returns true if `array` is a list, and `index` is either a valid index or the '-' append indicator
  """
  def is_array(array, index) do
    is_array_index(array, index) or is_array_append(array, index)
  end

  @doc """
  Parses a string representing a JSON pointer into an array of traversals.

  Returns `{:ok, list(traversals)}` when valid pointer
  Returns `{:error, :invalid_path}` when the path is invalid

  ## Rules (per RFC 6901)
  * pointers must start with a `/` character
  * the string `~1` is translated to `/`, but doesn't count for path separation
  * the string `~0` is translated to `~`, but doesn't effect `~1` parsing
  * integer keys are simply integers, not strings of integers

  ## Examples
      iex> Json.Pointer.parse("/foo/bar/4/baz")
      {:ok, ["foo", "bar", 4, "baz"]}

      iex> Json.Pointer.parse("")
      {:ok, []}

      iex> Json.Pointer.parse("/")
      {:ok, [""]}

      # parses numbers as ints only if they are the full key
      iex> Json.Pointer.parse("/8bar/9")
      {:ok, ["8bar", 9]}

      iex> Json.Pointer.parse(~S"/i\\j")
      {:ok, [~S"i\\j"]}

      iex> Json.Pointer.parse("/~10/~01/~0/~1")
      {:ok, ["/0", "~1", "~", "/"]}

      # require a leading /
      iex> Json.Pointer.parse("foo")
      {:error, :invalid_pointer}
  """
  def parse(path)

  # empty path is the whole document
  def parse(""), do: {:ok, []}

  # just the slash is the blank key
  def parse("/"), do: {:ok, [""]}

  # otherwise, strip the leading path, split, unescape, and attempt to resolve ints
  def parse("/" <> path) do
    path =
      path
      |> String.split("/")
      |> Enum.map(&unescape_key/1)
      |> Enum.map(&try_integer_key/1)

    {:ok, path}
  end

  # this is if pointer isn't a string, or doesn't start with /
  def parse(_),
    do: {:error, :invalid_pointer}

  defp unescape_key(part) do
    # order is important, see RFC 6901
    part
    |> String.replace("~1", "/", global: true)
    |> String.replace("~0", "~", global: true)
  end

  defp try_integer_key(part) do
    case Integer.parse(part) do
      # fully an int
      {num, ""} -> num
      # partially int
      {_, _} -> part
      # not even an int
      :error -> part
    end
  end

  @doc """
  Evaluate the given `pointer` in the context of `doc`.

  Returns `{:ok, value}` when the pointer is valid, and the document has a value at that path
  Returns `{:error, :invalid_pointer}` when the pointer is invalid (can't be parsed)
  Returns `{:error, :invalid_path}` when the document is invalid (can't be traversed)

  ## Examples

      iex> Json.Pointer.fetch(%{"foo" => %{"bar" => "baz"}}, "/foo/bar")
      {:ok, "baz"}

      iex> Json.Pointer.fetch(%{"foo" => [10, 11, 12, 13]}, "/foo/2")
      {:ok, 12}

      # it attempts parse first...
      iex> Json.Pointer.fetch(%{"foo" => 4}, "bad path")
      {:error, :invalid_pointer}

      # and fails if a good path isn't valid in the given object
      iex> Json.Pointer.fetch(%{"foo" => 4}, "/bad/path")
      {:error, :invalid_path}

      # you can also pass an already parsed path to fetch
      iex> Json.Pointer.fetch(%{"foo" => [10, 11, 12, 13]}, ["foo", 2])
      {:ok, 12}
  """
  def fetch(doc, pointer) when is_binary(pointer) do
    case Pointer.parse(pointer) do
      {:ok, path} -> fetch(doc, path)
      _error -> {:error, :invalid_pointer}
    end
  end

  # traverse against a map that contains the key
  def fetch(map, [key | path]) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> fetch(value, path)
      _error -> {:error, :invalid_path}
    end
  end

  # traverse against an array with a valid array index
  def fetch(array, [index | path]) when is_list(array) do
    case Enum.fetch(array, index) do
      {:ok, value} -> fetch(value, path)
      _error -> {:error, :invalid_path}
    end
  end

  # bottom of the recursion
  def fetch(value, []), do: {:ok, value}

  # not traversable
  def fetch(_, _), do: {:error, :invalid_path}

  @doc """
  Transform the given `document`, by transforming the value at `pointer`.

  ## Examples

      # given a callback of arity 1, transforms with the value at `path`
      iex> doc = %{"foo" => %{"bar" => [15]}}
      iex> Json.Pointer.transform(doc, "/foo/bar/0", &(&1 * 100))
      {:ok, %{"foo" => %{"bar" => [1500]}}}

      # given a callback of arity 2, transforms with the container and index
      iex> doc = %{"foo" => %{"bar" => 3}}
      iex> Json.Pointer.transform(doc, "/foo/bar", fn m, k -> Map.delete(m, k) end)
      {:ok, %{"foo" => %{}}}

      # transforms are allowed to return ok/error tuples in addition to bare values
      iex> doc = %{"foo" => [1]}
      iex> Json.Pointer.transform(doc, "/foo/0", fn i -> {:ok, i + 1} end)
      {:ok, %{"foo" => [2]}}

      # transforms are allowed to return ok/error tuples in addition to bare values
      iex> doc = %{"foo" => [1]}
      iex> Json.Pointer.transform(doc, "/foo/0", fn _, _ -> {:error, :oh_no_not_again} end)
      {:error, :oh_no_not_again}

      # gives errors on bad paths
      iex> doc = %{"foo" => %{"bar" => %{"baz" => 15}}}
      iex> Json.Pointer.transform(doc, "/foo/bar/cat", fn _ -> 100 end)
      {:error, :invalid_path}
  """
  def transform(document, pointer, callback) when is_binary(pointer) do
    case Pointer.parse(pointer) do
      {:ok, path} -> transform(document, path, callback)
      _error -> {:error, :invalid_pointer}
    end
  end

  # with callback arity = 1, we callback when we run out of path
  # allow the callback to return result tuple, or plain value
  def transform(document, [], callback) when is_function(callback, 1) do
    case callback.(document) do
      {:error, _} = error -> error
      {:ok, _} = success -> success
      value -> {:ok, value}
    end
  end

  # with callback arity = 2, we callback with the _container_ of the given path
  # allow the callback to return result tuple, or plain value
  def transform(document, [path | []], callback) when is_function(callback, 2) do
    case callback.(document, path) do
      {:error, _} = error -> error
      {:ok, _} = success -> success
      value -> {:ok, value}
    end
  end

  # transform a map key
  def transform(map, [key | path], callback) when is_map(map) do
    with {:ok, value} <- Map.fetch(map, key),
         {:ok, value} <- transform(value, path, callback) do
      {:ok, Map.put(map, key, value)}
    else
      # handle Map.fetch, evenything else is our own
      :error -> {:error, :invalid_path}
      error -> error
    end
  end

  # transform an array index
  def transform(array, [index | path], callback) when is_list(array) do
    with {:ok, value} <- Enum.fetch(array, index),
         {:ok, value} <- transform(value, path, callback) do
      {:ok, List.replace_at(array, index, value)}
    else
      # handle Enum.fetch, everything else is our own
      :error -> {:error, :invalid_path}
      error -> error
    end
  end

  # not traversable
  def transform(_, _, _), do: {:error, :invalid_path}
end
