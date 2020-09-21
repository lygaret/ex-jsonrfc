defmodule JsonRfc do
  @moduledoc """
  Typespecs and predicate functions for inspecting Json-like maps.
  """

  @type key :: String.t() | number
  @type value :: %{optional(key) => value} | [value] | String.t() | number | boolean | nil

  @doc """
  Returns true if `object` is a map containing only string keys.
  """
  @spec is_object(any) :: boolean
  def is_object(value) do
    is_map(value)
  end

  @doc """
  Returns true if `object` is a map containing the string key `key`, false otherwise.
  """
  @spec is_object_key(any, any) :: boolean
  def is_object_key(object, key) do
    is_map(object) and is_binary(key) and is_map_key(object, key)
  end

  @doc """
  Returns true if `array` is a list, `index` is an integer, and `index` isn't out of bounds.
  """
  @spec is_array_index(any, any) :: boolean
  def is_array_index(array, index) do
    is_list(array) and is_integer(index) and index >= 0 and length(array) > index
  end

  @doc """
  Returns true if `array` is a list, and `index` is the special 'append' indicator.
  """
  @spec is_array_append(any, any) :: boolean
  def is_array_append(array, index) do
    is_list(array) and index == "-"
  end

  @doc """
  Returns true if `array` is a list, and `index` is either a valid index or the '-' append indicator
  """
  @spec is_array(any, any) :: boolean
  def is_array(array, index) do
    is_array_index(array, index) or is_array_append(array, index)
  end
end
