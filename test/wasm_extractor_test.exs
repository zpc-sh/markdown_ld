defmodule MarkdownLd.WASMExtractorTest do
  use ExUnit.Case, async: true

  alias MarkdownLd.WASM

  test "extracts wasm module and config fences" do
    # minimal base64 payload (empty)
    md = """
    ```application/wasm {ldw:module=mod-1 ldw:entry=_start ldw:wasi=true}
    
    ```

    ```application/wasm+json {ldw:config-for=mod-1}
    {"entry":"_start","wasi":true}
    ```
    """

    items = WASM.extract(md)
    assert Enum.any?(items, &(&1.kind == :module and &1.id != nil and is_binary(&1.hash)))
    assert Enum.any?(items, &(&1.kind == :config and &1.id == "mod-1"))
  end

  test "diff detects wasm update" do
    md1 = """
    ```application/wasm {ldw:module=m1 ldw:entry=_start}
    AAA=
    ```
    """
    md2 = """
    ```application/wasm {ldw:module=m1 ldw:entry=_start}
    AAE=
    ```
    """

    changes = WASM.diff(md1, md2)
    kinds = changes |> Enum.map(& &1.kind) |> MapSet.new()
    assert MapSet.member?(kinds, :wasm_update)
  end

  test "projects wasm module to JSON-LD" do
    md = """
    ```application/wasm {ldw:module=m2 ldw:entry=_start ldw:policy=allow}
    AAE=
    ```
    """

    nodes = WASM.to_jsonld(md)
    assert Enum.any?(nodes, fn n ->
             n["@type"] == "wasm:Module" and n["schema:encodingFormat"] == "application/wasm"
           end)
  end
end

