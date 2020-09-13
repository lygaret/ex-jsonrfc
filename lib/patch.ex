defmodule Json.Patch do
  alias Json.Pointer

  @moduledoc """
  Represent map transformations as a series of JSON Patch (RFC 6902) compatible operations.
  """

  def add(pointer, value),
    do: %{op: :add, path: pointer, value: value}

  def replace(pointer, value),
    do: %{op: :replace, path: pointer, value: value}

  def remove(pointer),
    do: %{op: :remove, path: pointer}

  def move(from, path),
    do: %{op: :move, from: from, path: path}

  def copy(from, path),
    do: %{op: :copy, from: from, path: path}


  @doc """
  Given a list of `ops`, apply them all to the given document.
  Given a single operation, apply that operation to the given document.

  Operations are the maps returned from methods in this module, and represent
  the same named operations in IETF RFC 6902.

  ## Examples

      iex> doc = %{"foo" => [], "byebye" => 5}
      iex> ops = [
      ...>   Json.Patch.add("/bar", 3),
      ...>   Json.Patch.replace("/foo", %{}),
      ...>   Json.Patch.remove("/byebye"),
      ...>   Json.Patch.move("/bar", "/foo/bar"),
      ...>   Json.Patch.copy("/foo", "/baz")
      ...> ]
      iex> Json.Patch.evaluate(doc, ops)
      {:ok, %{"foo" => %{"bar" => 3}, "baz" => %{"bar" => 3}}}
  """
  def evaluate(document, ops)

  def evaluate(document, ops) when is_list(ops) do
    # reduce the operation list over the document, stopping on error
    Enum.reduce_while(ops, {:ok, document}, fn op, {:ok, doc} ->
      case evaluate(doc, op) do
        {:ok, result} -> {:cont, {:ok, result}}
        error -> {:halt, error}
      end
    end)
  end

  # Adds `value` to the `document` at `path`.
  # If a value is already present at `path` it is replaced.
  # Handles the array append operator to append to an array.
  # Shifts values right when inserting into an array
  def evaluate(document, %{op: :add, path: pointer, value: value}) do
    Pointer.transform(document, pointer, fn enum, key ->
      cond do
        Pointer.is_array_index(enum, key) ->
          {head, tail} = Enum.split(enum, key)
          {:ok, head ++ [value] ++ tail}

        Pointer.is_array_append(enum, key) ->
          {:ok, enum ++ [value]}

        is_map(enum) ->
          {:ok, Map.put(enum, key, value)}

        true ->
          {:error, :invalid_target}
      end
    end)
  end

  # Replaces the value at `path' with `value`.
  # Requires that there already exists a value at `path`, otherwise invalid target is returned.
  def evaluate(document, %{op: :replace, path: pointer, value: value}) do
    Pointer.transform(document, pointer, fn enum, key ->
      cond do
        Pointer.is_array_index(enum, key) ->
          {head, [_ | tail]} = Enum.split(enum, key)
          {:ok, head ++ [value] ++ tail}

        is_map(enum) and is_map_key(enum, key) ->
          {:ok, Map.replace!(enum, key, value)}

        true ->
          {:error, :invalid_target}
      end
    end)
  end

  # Removes the value at `path`.
  # shifts array elements left on removal
  # doesn't support array append
  def evaluate(document, %{op: :remove, path: pointer}) do
    Pointer.transform(document, pointer, fn enum, key ->
      cond do
        Pointer.is_array_index(enum, key) ->
          {head, [_ | tail]} = Enum.split(enum, key)
          {:ok, head ++ tail}

        is_map(enum) and is_map_key(enum, key) ->
          {:ok, Map.delete(enum, key)}

        true ->
          {:error, :invalid_target}
      end
    end)
  end

  def evaluate(document, %{op: :move, from: from, path: path}) do
    case Pointer.fetch(document, from) do
      {:ok, value} -> evaluate(document, [remove(from), add(path, value)])
      error -> error
    end
  end

  def evaluate(document, %{op: :copy, from: from, path: path}) do
    case Pointer.fetch(document, from) do
      {:ok, value} -> evaluate(document, add(path, value))
      error -> error
    end
  end
end
