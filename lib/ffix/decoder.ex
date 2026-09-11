defmodule FFix.Decoder do
  @moduledoc """
  Decoder shortcuts that configure streams on an input declaration.

  Named helpers return an updated `FFix.Command.Input`, preserving its identity.
  Every call requires an indexed selector. Only options are optional.

      input
      |> FFix.Decoder.h264({:video, 0}, threads: 2)
      |> FFix.Decoder.aac({:audio, 0}, threads: 1)

  All decoded uses of an input stream share its configuration. Independent
  decoding requires separate input declarations, even for the same source file.
  Decoder helpers do not operate on individual filter branches. Pass the updated
  input to stream selectors: existing streams retain their captured input snapshot.
  Repeated decoder configuration replaces the previous value for that selector.
  Use either absolute `{:index, n}` or media-relative `{media, n}` selectors on one
  input, not both: they can overlap, and FFix does not probe to resolve that ambiguity.

  Named helpers check options against recorded metadata without querying FFmpeg.
  Reported defaults are not emitted, strings remain open FFmpeg values, and
  `raw: [{"new_option", "value"}]` bypasses metadata checks for particular options.
  Registration in the baseline does not guarantee availability in another build.

  `decode/4` forwards codec or decoder names and options without a metadata schema.
  `auto/3` leaves decoder selection to FFmpeg. `new/2` constructs an unbound
  configuration for the lower-level model.
  """

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc "Builds an unbound configuration without metadata lookup."
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Command.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc "Configures one explicitly indexed input stream using a codec or decoder name."
  @spec decode(Input.t(), String.t() | nil, Input.decoder_selector(), list()) :: Input.t()
  def decode(input, name, selector, options \\ []) do
    unless is_struct(input, Input) do
      raise ArgumentError, "decoder configuration expects an input declaration, not a stream"
    end

    options = Options.normalize!(options, nil, "#{name || "automatic"} decoder")
    decoder = new(name, options)
    Command.validate_decoder!(selector, decoder)
    %{input | decoders: Map.put(input.decoders, selector, decoder)}
  end

  @doc "Configures one indexed input stream without forcing a decoder implementation."
  @spec auto(Input.t(), Input.decoder_selector(), list()) :: Input.t()
  def auto(input, selector, options \\ []), do: decode(input, nil, selector, options)

  defp check_media!(selector, media) do
    selected_media = FFix.Graph.InputRef.media(selector)

    if media != nil and selected_media != :unknown and selected_media != media do
      raise ArgumentError, "expected an indexed #{media} selector, got: #{inspect(selector)}"
    end
  end

  require FFix.Helpers
  FFix.Helpers.define(:decoder)
end
