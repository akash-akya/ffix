defmodule FFix.SelectionIntegrationTest do
  use ExUnit.Case, async: false

  alias FFix.{Encoder, Filter, Muxer}
  @ffmpeg System.find_executable("ffmpeg")
  @ffprobe System.find_executable("ffprobe")
  @moduletag skip: is_nil(@ffmpeg) or is_nil(@ffprobe)

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "ffix-selections-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    captions = Path.join(directory, "captions.srt")
    attachment = Path.join(directory, "attachment.txt")
    File.write!(captions, "1\n00:00:00,000 --> 00:00:00,500\nExample\n")
    File.write!(attachment, "FFix attachment\n")
    source = Path.join(directory, "source.mkv")

    ffmpeg!([
      "-f",
      "lavfi",
      "-i",
      "color=c=red:s=64x48:r=5:d=0.6",
      "-f",
      "lavfi",
      "-i",
      "color=c=blue:s=96x64:r=5:d=0.6",
      "-f",
      "lavfi",
      "-i",
      "sine=f=440:r=44100:d=0.6",
      "-f",
      "lavfi",
      "-i",
      "sine=f=880:r=44100:d=0.6",
      "-i",
      captions,
      "-map",
      "2:a",
      "-map",
      "0:v",
      "-map",
      "3:a",
      "-map",
      "1:v",
      "-map",
      "4:s",
      "-c:a",
      "pcm_s16le",
      "-ac:a:0",
      "2",
      "-c:v",
      "mpeg4",
      "-threads:v",
      "1",
      "-c:s",
      "srt",
      "-metadata:s:a:0",
      "language=eng",
      "-metadata:s:a:1",
      "language=jpn",
      "-attach",
      attachment,
      "-metadata:s:t:0",
      "mimetype=text/plain",
      source
    ])

    single_audio = Path.join(directory, "one-audio.mkv")
    ffmpeg!(["-i", source, "-map", "0:a:0", "-map", "0:v:0", "-c", "copy", single_audio])
    {:ok, directory: directory, source: source, single_audio: single_audio}
  end

  test "copies every stream and preserves both language tracks", %{
    directory: directory,
    source: path
  } do
    input = FFix.input(path)
    target = Path.join(directory, "copy-all.mkv")
    output = input |> FFix.select(:all) |> FFix.stream_copy() |> Muxer.matroska(target)
    run!(output)
    assert inventory(target) == inventory(path)
    assert length(inventory(target)) == 6
  end

  test "copies every video without copying audio or re-encoding the second video", %{
    directory: directory,
    source: path
  } do
    target = Path.join(directory, "copy-video.mkv")
    run!(FFix.input(path) |> FFix.video(:all) |> FFix.stream_copy() |> Muxer.matroska(target))
    assert [first, second] = inventory(target)
    assert first["codec_type"] == "video" and second["codec_type"] == "video"
    assert first["codec_name"] == "mpeg4" and second["codec_name"] == "mpeg4"
    assert first["width"] == 64 and second["width"] == 96
  end

  test "audio count cannot shift individually configured video tracks", %{
    directory: directory,
    source: source,
    single_audio: single_audio
  } do
    for {path, audio_count} <- [{source, 2}, {single_audio, 1}] do
      input = FFix.input(path)
      picture = FFix.video(input, 0)
      target = Path.join(directory, "mixed-#{audio_count}.mkv")

      output =
        Muxer.matroska(
          [
            FFix.stream_copy(FFix.audio(input, :all)),
            Encoder.ffv1(Filter.hflip(picture), threads: 1),
            Encoder.mpeg4(picture, threads: 1)
          ],
          target
        )

      run!(output)
      streams = inventory(target)
      assert length(streams) == audio_count + 2
      assert Enum.take(streams, audio_count) |> Enum.all?(&(&1["codec_name"] == "pcm_s16le"))
      assert Enum.map(Enum.drop(streams, audio_count), & &1["codec_name"]) == ["ffv1", "mpeg4"]
    end
  end

  test "uniform encoding applies to all selected videos while audio is copied", %{
    directory: directory,
    source: path
  } do
    input = FFix.input(path)
    target = Path.join(directory, "encode-videos.mkv")

    run!(
      Muxer.matroska(
        [
          Encoder.ffv1(FFix.video(input, :all), threads: 1),
          FFix.stream_copy(FFix.audio(input, :all))
        ],
        target
      )
    )

    assert Enum.map(inventory(target), & &1["codec_name"]) == [
             "ffv1",
             "ffv1",
             "pcm_s16le",
             "pcm_s16le"
           ]
  end

  test "cover art is excluded explicitly and optional mapping can omit it", %{
    directory: directory,
    source: path
  } do
    cover = Path.join(directory, "cover.png")

    ffmpeg!([
      "-f",
      "lavfi",
      "-i",
      "color=c=green:s=32x32:d=0.1",
      "-frames:v",
      "1",
      "-threads:v",
      "1",
      cover
    ])

    album = Path.join(directory, "album.m4a")

    ffmpeg!([
      "-i",
      path,
      "-i",
      cover,
      "-map",
      "0:a:0",
      "-map",
      "1:v:0",
      "-c:a",
      "aac",
      "-c:v",
      "copy",
      "-disposition:v:0",
      "attached_pic",
      "-t",
      "0.6",
      album
    ])

    input = FFix.input(album)
    assert Enum.any?(inventory(album), &(&1["codec_name"] == "png"))

    cover_target = Path.join(directory, "selected-cover.mkv")
    run!(FFix.video(input, 0) |> FFix.stream_copy() |> Muxer.matroska(cover_target))

    assert [%{"codec_name" => "png"}] =
             Enum.map(inventory(cover_target), &Map.take(&1, ["codec_name"]))

    target = Path.join(directory, "without-cover.mkv")

    run!(
      Muxer.matroska(
        [
          FFix.stream_copy(FFix.video(input, 0, attached_pictures: false, optional: true)),
          FFix.stream_copy(FFix.audio(input, 0))
        ],
        target
      )
    )

    assert [%{"codec_type" => "audio"}] =
             Enum.map(inventory(target), &Map.take(&1, ["codec_type"]))

    missing =
      FFix.video(input, 0, attached_pictures: false)
      |> FFix.stream_copy()
      |> Muxer.matroska(Path.join(directory, "missing-video.mkv"))
      |> FFix.command()

    assert {:error, %FFix.Runner.Error{kind: :exit}} = run_bounded(missing)
  end

  defp run!(output) do
    command = FFix.command(output, global: [y: :flag, loglevel: :error])
    assert {:ok, _result} = run_bounded(command)
  end

  defp run_bounded(command) do
    task = Task.async(fn -> FFix.run(command, ffmpeg: @ffmpeg) end)
    assert {:ok, result} = Task.yield(task, 10_000) || Task.shutdown(task, :brutal_kill)
    result
  end

  defp ffmpeg!(arguments) do
    assert {:ok, _capture} =
             FFix.Discovery.Exec.run(["-nostdin", "-v", "error", "-y" | arguments],
               ffmpeg: @ffmpeg,
               timeout: 10_000
             )
  end

  defp inventory(path) do
    assert {:ok, %{output: output}} =
             FFix.Discovery.Exec.run(
               [
                 "-v",
                 "error",
                 "-show_entries",
                 "stream=codec_type,codec_name,channels,width,height:stream_tags=language",
                 "-of",
                 "compact=p=0",
                 path
               ],
               ffmpeg: @ffprobe,
               timeout: 10_000
             )

    for line <- String.split(output, "\n", trim: true) do
      for field <- String.split(line, "|", trim: true), into: %{} do
        [name, value] = String.split(field, "=", parts: 2)

        value =
          if name in ["width", "height", "channels"] and value != "N/A",
            do: String.to_integer(value),
            else: value

        {name, value}
      end
    end
  end
end
