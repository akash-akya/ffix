defmodule FFix.Helpers.GeneratorTest do
  use ExUnit.Case, async: true

  alias FFix.Helpers.Generator

  @root Path.expand("../../..", __DIR__)

  test "checked-in helper functions regenerate from the recorded baseline" do
    {snapshot, []} = Code.eval_file(Path.join(@root, "priv/ffmpeg/helpers.exs"))

    for kind <- [:encoder, :decoder, :muxer, :demuxer] do
      source = File.read!(Path.join(@root, "lib/ffix/#{kind}.ex"))
      assert Generator.update(source, snapshot, kind) == source
    end
  end

  test "long descriptions and literal Elixir syntax survive generated documentation" do
    literal = ~S(Quotes """, interpolation #{not_code}, and a literal \n.)
    description = String.duplicate("Description. ", 500) <> literal

    snapshot = %{
      version: %{version: "fixture"},
      shared: [],
      components: [
        %{
          kind: :encoder,
          names: ["fixture_encoder"],
          media_type: :video,
          description: description,
          properties: [{"General capabilities", "dr1 delay threads "}],
          option_sections: []
        }
      ]
    }

    source = """
    defmodule Fixture do
      # BEGIN GENERATED HELPERS
      # END GENERATED HELPERS
    end
    """

    generated = Generator.update(source, snapshot, :encoder)
    quoted = Code.string_to_quoted!(generated)

    {_quoted, docs} =
      Macro.prewalk(quoted, [], fn node, docs ->
        case node do
          {:@, _metadata, [{:doc, _attribute_metadata, [doc]}]} -> {node, [doc | docs]}
          _other -> {node, docs}
        end
      end)

    assert [doc] = docs
    assert is_binary(doc)
    assert doc =~ description
    assert doc =~ "General capabilities: dr1 delay threads\n"

    Enum.each(String.split(generated, "\n"), fn line ->
      assert line == String.trim_trailing(line)
    end)
  end
end
