defmodule QCPParserTest do
  use ExUnit.Case, async: true

  test "parses simple format and defaults missing channels" do
    qcp = """
    ```task
    Analyze the user authentication flow
    ```

    ```resources
    File: lib/kyozo/accounts/user.ex
    Documentation: /docs/auth.md
    ```
    """
    m = QCP.parse(qcp)
    assert m.task =~ "Analyze the user authentication flow"
    assert m.resources =~ "lib/kyozo/accounts/user.ex"
    assert m.diagnostics == ""
    assert m.meta == ""
  end

  test "order independence and merging multiple channel blocks" do
    qcp = """
    ```resources
    A
    ```
    ```task
    T1
    ```
    ```task
    T2
    ```
    """
    m = QCP.parse(qcp)
    assert m.task == "T1\n\nT2"
    assert m.resources == "A"
  end

  test "complex multi-step example" do
    qcp = """
    ```task
    1. Review storage abstraction pattern
    2. Identify optimization opportunities
    3. Generate refactoring plan
    ```

    ```resources
    Storage implementations: lib/kyozo/storage/*.ex
    Performance metrics: /metrics/storage.json
    Current issues: #storage-slow-writes
    ```

    ```diagnostics
    Recursion_depth: MAX_3
    Semantic_saturation: MONITOR
    Processing_cycles: 10
    COGNITIVE_LOAD: AUTO_CALCULATE
    ```

    ```meta
    Cognitive_state: Stable after previous interrupt
    Avoided_patterns: Deep inheritance analysis
    ```
    """
    m = QCP.parse(qcp)
    assert m.task =~ "Review storage abstraction pattern"
    assert m.resources =~ "lib/kyozo/storage"
    assert m.diagnostics =~ "Recursion_depth"
    assert m.meta =~ "Cognitive_state"
  end
end

