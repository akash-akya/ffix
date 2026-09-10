defmodule FFix.DiscoveryIntegrationTest do
  use ExUnit.Case, async: true

  alias FFix.Discovery

  @moduletag :integration
  @help_kinds [:encoder, :decoder, :muxer, :demuxer, :filter, :bitstream_filter, :protocol]
  @ffmpeg System.find_executable(System.get_env("FFMPEG_BIN") || "ffmpeg")

  if is_nil(@ffmpeg) do
    @moduletag skip: "ffmpeg is required for discovery integration tests"
  end

  test "discovers catalogs and representative help from the installed build" do
    for kind <- Discovery.kinds() do
      assert {:ok, entries} = Discovery.list(kind, ffmpeg: @ffmpeg)
      assert is_list(entries)
      assert_help(kind, entries)
    end

    assert {:ok, version} = Discovery.version(ffmpeg: @ffmpeg)
    assert version.executable == @ffmpeg
    assert version.version != ""

    assert {:ok, shared} = Discovery.shared(ffmpeg: @ffmpeg)
    assert Enum.any?(shared, &(&1.name == "AVCodecContext"))
    assert Enum.any?(shared, &(&1.name == "AVFormatContext"))
  end

  defp assert_help(kind, [%{names: [name | _aliases]} | _entries]) when kind in @help_kinds do
    case Discovery.help(kind, name, ffmpeg: @ffmpeg) do
      {:ok, details} -> assert name in details.names
      {:error, %{reason: :help_unavailable}} when kind == :protocol -> :ok
      other -> flunk("#{kind}=#{name}: #{inspect(other)}")
    end
  end

  defp assert_help(_kind, _entries), do: :ok
end
