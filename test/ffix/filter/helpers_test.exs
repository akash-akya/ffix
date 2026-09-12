defmodule FFix.Filter.HelpersTest do
  use ExUnit.Case, async: false

  alias FFix.Filter
  alias FFix.Filter.Helpers
  alias FFix.Filter.Metadata
  alias FFix.Filter.Schema
  alias FFix.Graph
  alias FFix.Graph.StreamRef
  alias FFix.Graph.Terminal

  @metadata_path Path.expand("../../../priv/ffmpeg/metadata.exs", __DIR__)

  test "every recorded registration has ordinary helpers, full-arity specs and literal docs" do
    {metadata, []} = Code.eval_file(@metadata_path)
    assert length(metadata.filters) == 551
    assert map_size(Metadata.filters()) == 551
    assert Filter.__info__(:macros) == []
    {:ok, specs} = Code.Typespec.fetch_specs(Filter)

    {:docs_v1, _annotation, :elixir, _format, _moduledoc, _metadata, docs} =
      Code.fetch_docs(Filter)

    for %{registration: registration, help: help} <- metadata.filters do
      assert registration.kind == :filter
      assert help.kind == :filter
      assert registration.names == help.names
      [name] = registration.names
      function_name = String.to_atom(name)

      input_count =
        case registration.inputs do
          "|" -> 0
          signature -> String.length(signature)
        end

      full_arity = input_count + 1

      assert Keyword.get_values(Filter.__info__(:functions), function_name) ==
               [input_count, full_arity]

      assert List.keymember?(specs, {function_name, full_arity}, 0)

      assert {{:function, ^function_name, ^full_arity}, _annotation, _signature, %{"en" => doc},
              %{defaults: 1, group: group}} =
               Enum.find(docs, &(elem(&1, 0) == {:function, function_name, full_arity}))

      assert doc =~ registration.description
      assert doc =~ "See `FFix.Filter`"
      assert group in ["Video", "Audio", "Sources and sinks", "Other filters"]
    end

    normalized = Schema.normalize!(metadata.filters)
    assert normalized.filters == Metadata.filters()

    for {name, spec} <- normalized.specs do
      assert Metadata.filter_spec(name) == spec
    end

    generated_exports =
      Enum.reject(Filter.__info__(:functions), fn {name, _arity} -> name == :filter end)

    assert length(generated_exports) == 1_102
  end

  test "metadata and generated helpers both track the recorded snapshot" do
    for module <- [Metadata, Filter] do
      resources =
        module.__info__(:attributes) |> Keyword.get_values(:external_resource) |> List.flatten()

      assert @metadata_path in resources
    end
  end

  test "named helpers retain source, sink, fixed, dynamic and multi-output containers" do
    video = Graph.input(0, :video)
    other_video = Graph.input(1, :video)
    audio = Graph.input(0, :audio)

    assert %StreamRef{} = Filter.testsrc()
    assert %StreamRef{} = Filter.scale(video, w: 1280, h: -1)
    assert %StreamRef{} = Filter.overlay(video, other_video)
    assert %StreamRef{} = Filter.hstack([video, other_video])
    assert %StreamRef{} = Filter.threshold(video, video, video, video)
    assert %Terminal{} = Filter.nullsink(video)
    assert %Terminal{} = Filter.anullsink(audio)
    assert [%StreamRef{}, %StreamRef{}] = Filter.scale2ref(video, other_video)
    assert [%StreamRef{media: :audio}, %StreamRef{media: :video}] = Filter.avsynctest()
    assert %StreamRef{} = Filter.split(video, outputs: 1)
    assert [%StreamRef{}, %StreamRef{}] = Filter.split(video)
    assert [%StreamRef{}, %StreamRef{}] = Filter.asplit(audio)
    assert %StreamRef{} = Filter.concat([video, other_video])

    assert [%StreamRef{media: :video}, %StreamRef{media: :audio}] =
             Filter.concat([video, audio, other_video, audio], v: 1, a: 1)
  end

  test "named helper output counts honor aliases and positional options" do
    video = Graph.input(0, :video)
    audio = Graph.input(0, :audio)

    assert [%StreamRef{}, %StreamRef{}] = Filter.select(video, n: 2)
    assert [%StreamRef{}, %StreamRef{}, %StreamRef{}] = Filter.split(video, pos: 3)
    assert [%StreamRef{}, %StreamRef{}] = Filter.asplit(audio, pos: 3, outputs: 2)
    assert [%StreamRef{}, %StreamRef{}] = Filter.select(video, outputs: 3, n: 2)
  end

  test "filter helpers preserve arrays, raw strings, expressions, flags and positional order" do
    audio = Graph.input(0, :audio)
    formatted = Filter.aformat(audio, sample_rates: ["44100", 48000], sample_fmts: [:fltp, :s16])
    graph = FFix.graph(output: formatted)

    assert FFix.to_filtergraph(graph) ==
             "[0:a]aformat=sample_rates=44100|48000:sample_fmts=fltp|s16[out0];"

    assert arguments(Filter.aformat(audio, sample_rates: "44100|48000")) ==
             [{"sample_rates", "44100|48000"}]

    video = Graph.input(0, :video)
    expression = "between(t,1,2)"

    assert arguments(Filter.fade(video, type: :out, start_frame: "2")) ==
             [{"type", "out"}, {"start_frame", "2"}]

    assert arguments(Filter.drawtext(video, text_align: [], enable: expression)) ==
             [{"text_align", ""}, {"enable", expression}]

    assert arguments(Filter.scale(video, pos: 1280, pos: -1)) == [pos: "1280", pos: "-1"]
    assert arguments(Filter.scale(video, w: 1280, w: "iw/2")) == [{"w", "1280"}, {"w", "iw/2"}]

    assert_raise ArgumentError, ~r/vendor_option is not a valid option/, fn ->
      Filter.null(video, vendor_option: :literal)
    end

    assert arguments(Filter.filter(video, "null", [:video], vendor_option: :literal)) ==
             [{"vendor_option", "literal"}]
  end

  test "specs describe dynamic singleton results and permissive filter values" do
    assert signature(:split, 2) =~
             "FFix.Graph.StreamRef.t() | [FFix.Graph.StreamRef.t()]"

    assert signature(:concat, 2) =~
             "FFix.Graph.StreamRef.t() | [FFix.Graph.StreamRef.t()]"

    assert signature(:split, 2) =~ "FFix.Graph.Terminal.t()"
    assert signature(:nullsink, 2) =~ "FFix.Graph.Terminal.t()"

    assert signature(:scale2ref, 3) =~
             "[FFix.Graph.StreamRef.t()]"

    for name <- [:scale, :fade, :aformat, :drawtext] do
      spec = signature(name, 2)
      assert spec =~ "String.t()"
      refute spec =~ "FFix.Graph.Expr.t()"
      assert spec =~ "number()"
      assert spec =~ "atom()"
      assert spec =~ "pos:"
      refute spec =~ "option_callback"
      refute spec =~ "raw:"
    end

    array_type = Helpers.build_options_typespec(%{rates: %{type: {:array, :int}}})

    assert Macro.to_string(array_type) =~
             "[String.t() | atom() | number()]"

    assert Macro.to_string(Helpers.build_options_typespec(%{})) == "keyword()"
  end

  test "option and constant descriptions only add separators when present" do
    Enum.each(["", " \t\n", nil], fn blank ->
      options = %{
        mode: %{
          type: :int,
          desc: blank,
          sub: [
            %{enum: "dc_luma", num: "0", desc: blank},
            %{enum: "all", num: "", desc: "Run every test"}
          ]
        },
        rate: %{type: :int, desc: "Set frame rate"}
      }

      assert Helpers.build_options_doc(options) ==
               "- `mode` (int)\n" <>
                 "    - `dc_luma` (0)\n" <>
                 "    - `all` — Run every test\n" <>
                 "- `rate` (int): Set frame rate"
    end)
  end

  test "literal metadata generates ordinary functions without source rewriting" do
    literal = ~S(Quotes """, interpolation #{not_code}, and a literal \n.)
    metadata = fixture_metadata(literal)
    definitions = Helpers.definitions(metadata)
    assert definitions == FFix.Helpers.definitions(metadata, :filter)

    quoted = quote(do: (unquote_splicing(definitions)))
    docs = literal_docs(quoted)
    assert [doc] = docs
    assert doc =~ literal
    assert doc =~ "`custom` (string): #{literal}"
    assert doc =~ "See `FFix.Filter`"

    {:module, module, _bytecode, _result} =
      Module.create(__MODULE__.LiteralFilter, quoted, Macro.Env.location(__ENV__))

    on_exit(fn ->
      :code.delete(module)
      :code.purge(module)
    end)

    assert module.__info__(:macros) == []
    assert module.__info__(:functions) == [fixture_filter: 1, fixture_filter: 2]
    stream = apply(module, :fixture_filter, [Graph.input(0, :video), [custom: literal]])
    assert arguments(stream) == [{"custom", literal}]
  end

  test "filter generation rejects a collision with the generic operation" do
    metadata = fixture_metadata("Fixture")
    [entry] = metadata.filters
    entry = put_in(entry.registration.names, ["filter"])
    entry = put_in(entry.help.names, ["filter"])

    assert_raise ArgumentError,
                 "filter helper name conflicts with the generic filter operation",
                 fn ->
                   Helpers.definitions(%{metadata | filters: [entry]})
                 end
  end

  test "macro generation and helper construction need no installed FFmpeg" do
    previous = System.get_env() |> Map.take(["FFMPEG_BIN", "PATH"])
    System.put_env("FFMPEG_BIN", "/nonexistent/ffix-filter-helpers-test/ffmpeg")
    System.put_env("PATH", "")

    on_exit(fn ->
      for name <- ["FFMPEG_BIN", "PATH"] do
        case Map.fetch(previous, name) do
          {:ok, value} -> System.put_env(name, value)
          :error -> System.delete_env(name)
        end
      end

      :code.delete(__MODULE__.OfflineFilter)
      :code.purge(__MODULE__.OfflineFilter)
    end)

    quoted =
      quote do
        require FFix.Helpers
        FFix.Helpers.define(:filter)
      end

    {:module, module, _bytecode, _result} =
      Module.create(__MODULE__.OfflineFilter, quoted, Macro.Env.location(__ENV__))

    video = Graph.input(0, :video)
    assert [%StreamRef{}, %StreamRef{}] = apply(module, :split, [video])
    assert %StreamRef{} = apply(module, :scale, [video, [w: 1280]])
    assert length(module.__info__(:functions)) == 1_102
  end

  defp arguments(stream) do
    text = FFix.to_filtergraph(FFix.graph(output: stream))
    [chain: [filter]] = FFix.Parsers.FilterGraph.parse(text)
    FFix.Parsers.FilterGraph.parse_args(filter.args)
  end

  defp signature(name, arity) do
    {:ok, specs} = Code.Typespec.fetch_specs(Filter)
    {{^name, ^arity}, [spec]} = List.keyfind(specs, {name, arity}, 0)
    spec |> then(&Code.Typespec.spec_to_quoted(name, &1)) |> Macro.to_string()
  end

  defp literal_docs(quoted) do
    {_quoted, docs} =
      Macro.prewalk(quoted, [], fn node, docs ->
        case node do
          {:@, _metadata, [{:doc, _attribute_metadata, [doc]}]} when is_binary(doc) ->
            {node, [doc | docs]}

          _other ->
            {node, docs}
        end
      end)

    docs
  end

  defp fixture_metadata(literal) do
    %{
      version: %{version: "fixture"},
      filters: [
        %{
          registration: %{
            kind: :filter,
            names: ["fixture_filter"],
            inputs: "V",
            outputs: "V",
            flags: "...",
            description: literal
          },
          help: %{
            kind: :filter,
            names: ["fixture_filter"],
            inputs: [%{index: 0, name: "default", media_type: "video"}],
            outputs: [%{index: 0, name: "default", media_type: "video"}],
            option_sections: [
              %{
                name: "Fixture owner",
                options: [
                  %{
                    name: "custom",
                    type: :string,
                    flags: "..FV.......",
                    help: literal,
                    declared_default: nil,
                    ranges: [],
                    constants: []
                  }
                ]
              }
            ]
          }
        }
      ]
    }
  end
end
