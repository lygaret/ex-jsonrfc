defmodule JsonRfc.Pointer do
  @moduledoc ~s"""
  Fetch and transform data in Maps by evaluating JSON pointers
  """

  @doc """
  Parses a string representing a JSON pointer into an array of traversals.

  ## Rules (per RFC 6901)
  * pointers must start with a `/` character
  * the string `~1` is translated to `/`, but doesn't count for path separation
  * the string `~0` is translated to `~`, but doesn't effect `~1` parsing
  * integer keys are simply integers, not strings of integers

  ## Examples
      iex> JsonRfc.Pointer.parse("/foo/bar/4/baz")
      {:ok, ["foo", "bar", 4, "baz"]}

      iex> JsonRfc.Pointer.parse("whatever")
      {:error, :invalid_pointer}
  """

  @type path :: [JsonRfc.key()]
  @spec parse(iodata) :: {:ok, path} | {:error, :invalid_pointer}

  def parse(path) do
    case path do
      # empty path is the whole document
      "" ->
        {:ok, []}

      # just the slash is the blank key
      "/" ->
        {:ok, [""]}

      # leading slash gets parsed
      "/" <> path ->
        path =
          path
          |> String.split("/")
          |> Enum.map(&unescape_key/1)
          |> Enum.map(&try_integer_key/1)

        {:ok, path}

      # this is if pointer isn't a string, or doesn't start with /
      _ ->
        {:error, :invalid_pointer}
    end
  end

  @spec unescape_key(String.t()) :: String.t()
  defp unescape_key(part) do
    # order is important, see RFC 6901
    part
    |> String.replace(~S(\"), "\"", global: true)
    |> String.replace(~S(\\), "\\", global: true)
    |> String.replace("~1", "/", global: true)
    |> String.replace("~0", "~", global: true)
  end

  @spec try_integer_key(String.t()) :: integer | binary
  defp try_integer_key(part) do
    case part do
      "0" ->
        0

      # leading zero can only be a string per RFC, see specs
      "0" <> _ ->
        part

      # parse returns {num, "rest"} or error; if rest exists, it's not a number
      # we're probably overly generous, but strictness isn't a goal
      _ ->
        case Integer.parse(part) do
          {num, ""} -> num
          {_, _} -> part
          :error -> part
        end
    end
  end

  @doc """
  Evaluate the given `pointer` in the context of `doc`.

  Returns `{:ok, value}` when the pointer is valid, and the document has a value at that path
  Returns `{:error, :invalid_pointer}` when the pointer is invalid (can't be parsed)
  Returns `{:error, :invalid_path}` when the document is invalid (can't be traversed)

  ## Examples

      iex> JsonRfc.Pointer.fetch(%{"foo" => [%{"bar" => "baz"}]}, "/foo/0/bar")
      {:ok, "baz"}
  """

  @type fetch_errors :: {:error, :invalid_pointer} | {:error, :invalid_path}
  @spec fetch(JsonRfc.value(), binary) :: {:ok, JsonRfc.value()} | fetch_errors
  @spec fetch(JsonRfc.value(), path) :: {:ok, JsonRfc.value()} | fetch_errors

  # parse the pointer if it's a string
  def fetch(doc, pointer) when is_binary(pointer) do
    with {:ok, path} <- parse(pointer) do
      fetch(doc, path)
    end
  end

  # traverse against a map that contains the key
  # if key is a number, convert to a string before indexing:
  # parse con't know context, so integer keys may be present, but
  # JSON objects can have only string keys per RFC
  def fetch(map, [key | path]) when is_map(map) do
    key = if is_number(key), do: Integer.to_string(key), else: key

    case Map.fetch(map, key) do
      {:ok, value} -> fetch(value, path)
      _error -> {:error, :invalid_path}
    end
  end

  # traverse against an array
  # - if the index isn't an int or present, invalid path
  def fetch(array, [index | path]) when is_list(array) do
    with true <- JsonRfc.is_array_index(array, index),
         {:ok, value} <- Enum.fetch(array, index) do
      fetch(value, path)
    else
      _error -> {:error, :invalid_path}
    end
  end

  # bottom of the recursion
  def fetch(value, []), do: {:ok, value}

  # not traversable
  def fetch(_, _), do: {:error, :invalid_path}

  @doc """
  Transform the given `document`, by transforming the value at `pointer`.

  Given a callback of arity 1, the callback recieves the value at `path`, and the
  return value is place directly at `path`.

  Given a callback of arity 2, however, the callback recieves the value *containing the key* given by `path`,
  and the return value replaces the *container*. This allows handling immutable containers: you can replace
  the container with a call to `Map.delete/2` for example.

  Callbacks may return a bare value, or a result tuple (:ok/:error).

  ## Examples

      # given a callback of arity 1, transforms with the value at `path`
      iex> doc = %{"foo" => %{"bar" => [15]}}
      iex> JsonRfc.Pointer.transform(doc, "/foo/bar/0", &(&1 * 100))
      {:ok, %{"foo" => %{"bar" => [1500]}}}

      # given a callback of arity 2, transforms with the container and index
      iex> doc = %{"foo" => %{"bar" => 3}}
      iex> JsonRfc.Pointer.transform(doc, "/foo/bar", &Map.delete(&1, &2))
      {:ok, %{"foo" => %{}}}
  """

  @spec transform(JsonRfc.value(), binary(), (JsonRfc.value() -> JsonRfc.value())) ::
          {:ok, JsonRfc.value()} | {:error, term}

  @spec transform(JsonRfc.value(), path(), (JsonRfc.value() -> JsonRfc.value())) ::
          {:ok, JsonRfc.value()} | {:error, term}

  @spec transform(JsonRfc.value(), binary(), (JsonRfc.value(), JsonRfc.key() -> JsonRfc.value())) ::
          {:ok, JsonRfc.value()} | {:error, term}

  @spec transform(JsonRfc.value(), path(), (JsonRfc.value(), JsonRfc.key() -> JsonRfc.value())) ::
          {:ok, JsonRfc.value()} | {:error, term}

  def transform(document, pointer, callback) when is_binary(pointer) do
    with {:ok, path} <- parse(pointer) do
      transform(document, path, callback)
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
