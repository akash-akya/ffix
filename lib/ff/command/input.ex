defmodule FF.Command.Input do
  @moduledoc """
  One ffmpeg input declaration.

  ## Examples

      src = FF.Command.input("input.mp4", ss: "00:00:03")
      logo = FF.Command.input("logo.png", label: :logo, loop: 1, framerate: 1)

      src[:input]
      src[:video]
      src[:audio]
      src[audio: 1]
      logo[:video]
  """

  @behaviour Access

  @type source :: String.t() | :stdin | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}
  @type label :: String.t()

  @type t :: %__MODULE__{
          source: source(),
          id: reference() | nil,
          label: label() | nil,
          options: [option()]
        }

  defstruct [:source, :id, :label, options: []]

  @spec fetch(t(), term()) :: {:ok, FF.Stream.t()} | :error
  def fetch(%__MODULE__{id: id}, key) when is_reference(id) do
    {:ok, FF.Graph.input(id, selector_from_access!(key))}
  end

  def fetch(%__MODULE__{}, _key) do
    raise ArgumentError, "command input access requires an input created with FF.Command.input/2"
  end

  def get_and_update(%__MODULE__{}, _key, _fun) do
    raise ArgumentError, "FF.Command.Input access is read-only"
  end

  def pop(%__MODULE__{}, _key) do
    raise ArgumentError, "FF.Command.Input access is read-only"
  end

  defp selector_from_access!(:input), do: :input
  defp selector_from_access!(:video), do: :video
  defp selector_from_access!(:audio), do: :audio
  defp selector_from_access!(video: index), do: {:video, normalize_track_index!(index)}
  defp selector_from_access!(audio: index), do: {:audio, normalize_track_index!(index)}
  defp selector_from_access!(raw: selector), do: normalize_raw_selector!(selector)
  defp selector_from_access!({:video, index}), do: {:video, normalize_track_index!(index)}
  defp selector_from_access!({:audio, index}), do: {:audio, normalize_track_index!(index)}
  defp selector_from_access!({:raw, selector}), do: normalize_raw_selector!(selector)

  defp selector_from_access!(key) do
    raise ArgumentError,
          "invalid input selector #{inspect(key)}; expected :input, :video, :audio, [video: n], [audio: n], or {:raw, selector}"
  end

  defp normalize_track_index!(index) when is_integer(index) and index >= 0, do: index

  defp normalize_track_index!(index) do
    raise ArgumentError, "track index must be a non-negative integer, got: #{inspect(index)}"
  end

  defp normalize_raw_selector!(selector) when is_binary(selector) and selector != "",
    do: {:raw, selector}

  defp normalize_raw_selector!(selector) do
    raise ArgumentError, "raw selector must be a non-empty string, got: #{inspect(selector)}"
  end
end
