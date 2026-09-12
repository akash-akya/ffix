defmodule FFix.Decoder do
  @moduledoc """
  Configure how an input stream is decoded.

  FFmpeg normally chooses a decoder from the input's codec. Use this module to
  select an implementation or change decoding options, such as its thread count.
  Configure decoding on the input before selecting streams:

      alias FFix.{Decoder, Filter}

      source =
        FFix.input("interview.mp4")
        |> Decoder.h264({:video, 0}, threads: 2)

      picture = source |> FFix.video(0) |> Filter.scale(w: 640, h: -2)
      FFix.output(picture, "preview.mp4") |> FFix.command()

  This assumes H.264 video. `auto/3` applies options while letting FFmpeg choose
  the decoder. Output compression is configured separately with `FFix.Encoder`.

  ## Select the input track

  Decoder selectors identify one track:

  - `{:video, 0}` — the first video track.
  - `{:audio, 1}` — the second audio track.
  - `{:index, 3}` — stream 3, counting every stream in the file.

  Subtitle, data, and attachment selectors follow the same indexed form.
  Choose either media-relative selectors or absolute indexes for one input.
  Mixing them could configure the same track twice under different names.

  All uses of that input share its decoding settings. Declare the file twice if
  you need independent decoding or seeking. See `FFix.Command.Input` for input
  reuse. Configuring the same selector again replaces its previous decoder settings.

  Named helpers use the recorded option reference. Use `decode/4` for other
  decoder names and `raw:` for newer options, as described in `FFix.Encoder`.
  Availability can be checked through `FFix.Discovery`.

  See the [FFmpeg codec reference](https://ffmpeg.org/ffmpeg-codecs.html) for
  decoder-specific options.
  """

  alias FFix.Command
  alias FFix.Command.Input
  alias FFix.Options

  @type t :: %__MODULE__{name: String.t() | nil, options: [Command.av_option()]}
  defstruct [:name, options: []]

  @doc """
  Builds a decoder configuration for an input's `decoders:` map.

      decoder = FFix.Decoder.new("h264", threads: 2)
      FFix.input("interview.mp4", decoders: %{{:video, 0} => decoder})

  A `nil` name lets FFmpeg choose the decoder while applying the options.
  """
  @spec new(String.t() | nil, [Command.av_option()]) :: t()
  def new(name, options \\ []) do
    Options.validate_component!(%__MODULE__{name: name, options: options})
  end

  @doc """
  Configures an input track with an FFmpeg codec or decoder name and options.

      source = FFix.input("recording.flac")
      FFix.Decoder.decode(source, "flac", {:audio, 0})

  Returns the updated input. Select streams from this returned value so they
  use the new settings. Names and options are passed to FFmpeg.
  """
  @spec decode(Input.t(), String.t() | nil, Input.decoder_selector(), list()) :: Input.t()
  def decode(input, name, selector, options \\ []) do
    unless is_struct(input, Input) do
      raise ArgumentError, "decoder configuration expects an input declaration, not a stream"
    end

    options = Options.normalize!(options, nil, "#{name || "automatic"} decoder")
    decoder = new(name, options)
    Input.validate_decoder!(selector, decoder)
    %{input | decoders: Map.put(input.decoders, selector, decoder)}
  end

  @doc """
  Applies decoding options while FFmpeg chooses the implementation.

      FFix.input("interview.mp4") |> FFix.Decoder.auto({:video, 0}, threads: 2)
  """
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
