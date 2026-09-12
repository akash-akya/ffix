defmodule FFix.Graph.InputRef do
  @moduledoc false

  @media [:video, :audio, :subtitle, :data, :attachment]
  @selector_media @media ++ [:video_only]
  @type input_id :: non_neg_integer() | String.t() | reference()
  @type media :: :video | :audio | :subtitle | :data | :attachment
  @type selector ::
          :input
          | :all
          | media()
          | :video_only
          | {media() | :video_only, non_neg_integer() | :all}
          | {:index, non_neg_integer()}
          | {:raw, String.t()}

  @type t :: %__MODULE__{
          input: input_id(),
          selector: selector(),
          declaration: FFix.Command.Input.t() | nil
        }

  defstruct [:input, :selector, :declaration]

  @spec new(FFix.Command.Input.t() | input_id() | atom(), selector()) :: t()
  def new(input_or_id, selector) do
    selector = normalize_selector!(selector)

    case input_or_id do
      %FFix.Command.Input{id: id} = input ->
        unless is_reference(id) do
          raise ArgumentError,
                "captured inputs require an identity; construct inputs with Input.new/2"
        end

        %__MODULE__{input: id, selector: selector, declaration: input}

      input ->
        %__MODULE__{input: normalize_input_id!(input), selector: selector}
    end
  end

  @spec normalize_input_id!(non_neg_integer() | atom() | String.t() | reference()) :: input_id()
  def normalize_input_id!(input) when is_integer(input) and input >= 0, do: input
  def normalize_input_id!(input) when is_reference(input), do: input
  def normalize_input_id!(input) when is_atom(input), do: Atom.to_string(input)

  def normalize_input_id!(input) when is_binary(input) and input != "" do
    if String.contains?(input, <<0>>), do: raise(ArgumentError, "input id cannot contain NUL")
    input
  end

  def normalize_input_id!(input) do
    raise ArgumentError,
          "input id must be a non-negative integer, reference, atom, or non-empty string, got: #{inspect(input)}"
  end

  @spec normalize_selector!(term()) :: selector()
  def normalize_selector!(selector)
      when selector in [:input, :all] or selector in @selector_media,
      do: selector

  def normalize_selector!({media, index} = selector)
      when media in @selector_media and ((is_integer(index) and index >= 0) or index == :all),
      do: selector

  def normalize_selector!({:index, index} = selector) when is_integer(index) and index >= 0,
    do: selector

  def normalize_selector!({:raw, value} = selector) when is_binary(value) and value != "" do
    if String.contains?(value, <<0>>),
      do: raise(ArgumentError, "input selector cannot contain NUL")

    selector
  end

  def normalize_selector!(selector),
    do: raise(ArgumentError, "invalid input selector: #{inspect(selector)}")

  @spec media(selector()) :: media() | :unknown
  def media(selector) do
    case selector do
      :video_only -> :video
      {:video_only, _index} -> :video
      media when media in @media -> media
      {media, _index} when media in @media -> media
      _selector -> :unknown
    end
  end

  @spec single?(selector()) :: boolean()
  def single?(selector) do
    case selector do
      {media, index} when media in @selector_media and is_integer(index) and index >= 0 -> true
      {:index, index} when is_integer(index) and index >= 0 -> true
      _selector -> false
    end
  end

  @spec selector_string(selector()) :: String.t()
  def selector_string(selector) do
    case normalize_selector!(selector) do
      whole when whole in [:input, :all] -> ""
      media when media in @selector_media -> selector_prefix(media)
      {media, :all} when media in @selector_media -> selector_prefix(media)
      {media, index} when media in @selector_media -> "#{selector_prefix(media)}:#{index}"
      {:index, index} -> Integer.to_string(index)
      {:raw, value} -> value
    end
  end

  defp selector_prefix(:video_only), do: "V"
  defp selector_prefix(media), do: media_prefix(media)

  @spec media_prefix(media()) :: String.t()
  def media_prefix(media) do
    case media do
      :video -> "v"
      :audio -> "a"
      :subtitle -> "s"
      :data -> "d"
      :attachment -> "t"
    end
  end
end
