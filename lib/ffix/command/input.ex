defmodule FFix.Command.Input do
  @moduledoc """
  One ffmpeg input declaration.

  Accessing an input returns `FFix.Stream` references that can be used in graphs
  or mapped directly to outputs. The access keys mirror common ffmpeg stream
  selectors:

    * `input[:input]` maps the whole input, like `-map 0`
    * `input[:video]` maps the matching video streams, like `0:v`
    * `input[:audio]` maps the matching audio streams, like `0:a`
    * `input[audio: 1]` maps/selects a specific stream class index, like
      `0:a:1`
    * `input[raw: "s?"]` keeps an explicit ffmpeg selector escape hatch

  `demuxer` optionally selects and configures an `FFix.Demuxer`. Its AVOptions
  remain separate from raw input CLI options and are rendered before `-i`.

  `decoders` maps indexed selectors (`{:video, n}` or `{:audio, n}`) to
  `FFix.Decoder` configurations. Decoder options are rendered before this
  input's `-i`, independently of its position in the command. Updating this
  configuration preserves the input identity used by existing stream references.

  Keep decoder configuration separate from raw codec selections/options in
  `options`; conflicting option names are rejected rather than overridden.

  ## Examples

      src = FFix.Command.input("input.mp4", ss: "00:00:03")
      logo = FFix.Command.input("logo.png", loop: 1, framerate: 1)

      src[:input]
      src[:video]
      src[:audio]
      src[audio: 1]
      logo[:video]
  """

  @behaviour Access

  @type source :: String.t() | :stdin | {:pipe, non_neg_integer()} | {:url, String.t()}
  @type option :: {atom() | String.t(), term()}

  @type decoder_selector :: {:video | :audio, non_neg_integer()}

  @type t :: %__MODULE__{
          source: source(),
          id: reference() | nil,
          options: [option()],
          demuxer: FFix.Demuxer.t() | nil,
          decoders: %{decoder_selector() => FFix.Decoder.t()}
        }

  defstruct [:source, :id, :demuxer, options: [], decoders: %{}]

  @doc false
  @spec fetch(t(), term()) :: {:ok, FFix.Stream.t()} | :error
  def fetch(%__MODULE__{id: id}, key) when is_reference(id) do
    {:ok, FFix.Graph.input(id, selector_from_access!(key))}
  end

  def fetch(%__MODULE__{}, _key) do
    raise ArgumentError,
          "command input access requires an input created with FFix.Command.input/2"
  end

  @doc false
  def get_and_update(%__MODULE__{}, _key, _fun) do
    raise ArgumentError, "FFix.Command.Input access is read-only"
  end

  @doc false
  def pop(%__MODULE__{}, _key) do
    raise ArgumentError, "FFix.Command.Input access is read-only"
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
