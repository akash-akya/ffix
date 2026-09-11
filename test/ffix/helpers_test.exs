defmodule FFix.HelpersTest do
  use ExUnit.Case, async: false

  alias FFix.Helpers

  @metadata_path Path.expand("../../priv/ffmpeg/metadata.exs", __DIR__)
  @modules [
    encoder: FFix.Encoder,
    decoder: FFix.Decoder,
    muxer: FFix.Muxer,
    demuxer: FFix.Demuxer
  ]

  test "recorded registrations define ordinary functions, documentation, and option types" do
    {metadata, []} = Code.eval_file(@metadata_path)

    for entry <- metadata.components do
      module = Keyword.fetch!(@modules, entry.kind)
      assert module.__info__(:macros) == []
      {:ok, specs} = Code.Typespec.fetch_specs(module)
      {:ok, types} = Code.Typespec.fetch_types(module)

      {:docs_v1, _annotation, :elixir, _format, _moduledoc, _metadata, docs} =
        Code.fetch_docs(module)

      for name <- entry.names do
        function_name = String.to_atom(name)

        if String.match?(name, ~r/^[a-z][a-z0-9_]*$/) do
          arities =
            case entry.kind do
              kind when kind in [:muxer, :decoder] -> [2, 3]
              _other -> [1, 2]
            end

          actual_arities = Keyword.get_values(module.__info__(:functions), function_name)
          assert actual_arities == arities
          full_arity = List.last(arities)
          assert List.keymember?(specs, {function_name, full_arity}, 0)
          type_name = String.to_atom("#{name}_option")
          assert Enum.any?(types, &match?({:type, {^type_name, _definition, []}}, &1))

          assert {{:function, ^function_name, ^full_arity}, _annotation, _signature,
                  %{"en" => doc}, %{defaults: 1}} =
                   Enum.find(docs, &(elem(&1, 0) == {:function, function_name, full_arity}))

          assert doc =~ "#{name}: #{entry.description}"
          assert doc =~ "Metadata baseline: FFmpeg #{metadata.version.version}"
        else
          refute function_exported?(module, function_name, 2)
        end
      end
    end
  end

  test "each helper module tracks the recorded metadata as a compilation dependency" do
    for {_kind, module} <- @modules do
      resources =
        module.__info__(:attributes) |> Keyword.get_values(:external_resource) |> List.flatten()

      assert @metadata_path in resources
    end
  end

  test "option types retain callbacks, named bindings, flags, and input-only restrictions" do
    encoder_type = option_type(FFix.Encoder, :libx264_option)
    assert encoder_type =~ "FFix.Command.option_callback()"
    assert encoder_type =~ "FFix.Command.output_av_option()"
    assert encoder_type =~ "[String.t() | :"

    muxer_type = option_type(FFix.Muxer, :hls_option)
    assert muxer_type =~ "FFix.Command.option_callback()"
    assert muxer_type =~ ":output_options"

    for removed <- [":video", ":audio", ":sources"] do
      refute muxer_type =~ removed
    end

    {:ok, specs} = Code.Typespec.fetch_specs(FFix.Muxer)
    {{:hls, 3}, [spec]} = List.keyfind(specs, {:hls, 3}, 0)
    signature = Code.Typespec.spec_to_quoted(:hls, spec) |> Macro.to_string()
    assert signature =~ "FFix.Command.binding()"

    decoder_type = option_type(FFix.Decoder, :hevc_option)
    assert decoder_type =~ "FFix.Command.av_option()"
    refute decoder_type =~ "option_callback"
    refute decoder_type =~ "view_ids_available"
    refute option_type(FFix.Demuxer, :mov_option) =~ "option_callback"
  end

  test "literal metadata survives compilation without source escaping" do
    literal = ~S(Quotes """, interpolation #{not_code}, and a literal \n.)
    description = String.duplicate("Description. ", 500) <> literal
    metadata = fixture_metadata(["fixture_encoder"], description)
    definitions = Helpers.definitions(metadata, :encoder)

    quoted =
      quote do
        def encode(source, name, options), do: {source, name, options}
        unquote_splicing(definitions)
      end

    {:module, module, _bytecode, _result} =
      Module.create(__MODULE__.LiteralEncoder, quoted, Macro.Env.location(__ENV__))

    on_exit(fn ->
      :code.delete(module)
      :code.purge(module)
    end)

    assert apply(module, :fixture_encoder, [:source, [{"custom-option", literal}]]) ==
             {:source, "fixture_encoder", [{"custom-option", literal}]}

    {_quoted, docs} =
      Macro.prewalk(quoted, [], fn node, docs ->
        case node do
          {:@, _metadata, [{:doc, _attribute_metadata, [doc]}]} -> {node, [doc | docs]}
          _other -> {node, docs}
        end
      end)

    assert [doc] = docs

    assert doc =~ description
    assert doc =~ "General capabilities: dr1 delay threads\n"
    assert doc =~ "`custom-option` (Fixture AVOptions, :string): #{literal}"
    assert Enum.all?(String.split(doc, "\n"), &(&1 == String.trim_trailing(&1)))
  end

  test "invalid identifiers stay out of the helper API and reserved names fail explicitly" do
    metadata = fixture_metadata(["fixture_encoder", "3gp", "hyphen-name"], "Fixture")
    assert length(Helpers.definitions(metadata, :encoder)) == 1

    for name <- ~w(new encode decode mux demux auto build_input build_output) do
      metadata = fixture_metadata([name], "Fixture")

      assert_raise ArgumentError,
                   "helper name conflicts with an existing function: #{name}",
                   fn ->
                     Helpers.definitions(metadata, :encoder)
                   end
    end
  end

  test "macro expansion needs no installed FFmpeg" do
    previous = System.get_env("FFMPEG_BIN")
    System.put_env("FFMPEG_BIN", "/nonexistent/ffix-helpers-test/ffmpeg")

    on_exit(fn ->
      if previous,
        do: System.put_env("FFMPEG_BIN", previous),
        else: System.delete_env("FFMPEG_BIN")

      :code.delete(__MODULE__.OfflineEncoder)
      :code.purge(__MODULE__.OfflineEncoder)
    end)

    quoted =
      quote do
        require FFix.Helpers
        def encode(source, name, options), do: {source, name, options}
        FFix.Helpers.define(:encoder)
      end

    {:module, module, _bytecode, _result} =
      Module.create(__MODULE__.OfflineEncoder, quoted, Macro.Env.location(__ENV__))

    assert apply(module, :libx264, [:source, [crf: 18]]) ==
             {:source, "libx264", [{"crf", 18}]}
  end

  test "metadata refresh rejects obsolete generation arguments" do
    for arguments <- [["--check"], ["--refresh"], ["--ffmpeg"], ["unexpected"]] do
      assert_raise Mix.Error, "use mix ffix.refresh.metadata [--ffmpeg executable]", fn ->
        Mix.Tasks.Ffix.Refresh.Metadata.run(arguments)
      end
    end
  end

  defp option_type(module, name) do
    {:ok, types} = Code.Typespec.fetch_types(module)
    {:type, type} = Enum.find(types, &match?({:type, {^name, _definition, []}}, &1))
    type |> Code.Typespec.type_to_quoted() |> Macro.to_string()
  end

  defp fixture_metadata(names, description) do
    %{
      version: %{version: "fixture"},
      shared: [],
      components: [
        %{
          kind: :encoder,
          names: names,
          media_type: :video,
          description: description,
          properties: [{"General capabilities", "dr1 delay threads "}],
          option_sections: [
            %{
              name: "Fixture AVOptions",
              options: [
                %{
                  name: "custom-option",
                  type: :string,
                  flags: "E..V.......",
                  help: ~S(Quotes """, interpolation #{not_code}, and a literal \n.),
                  constants: []
                }
              ]
            }
          ]
        }
      ]
    }
  end
end
