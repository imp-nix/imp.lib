# File Reference

Source files in the imp library and their purposes.

## Core Files

### `src/default.nix`

Entry point. Exports the main `imp` API with all methods.

### `src/api.nix`

All chainable methods: `filter`, `map`, `tree`, `configTree`, `registry`, etc.

### `src/lib.nix`

Internal utilities used by other modules.

## Import & Collection

### `src/collect.nix`

File collection and filtering logic. Handles:

- Recursive directory traversal
- `.nix` file detection
- Hidden file (`_` prefix) exclusion
- Naming convention application

### `src/tree.nix`

Tree building from directories. Converts directory structure to nested attrsets.

## Config Trees

### `src/configTree.nix`

Directory structure to option path mapping. Powers the `configTree` method.

### `src/mergeConfigTrees.nix`

Merge multiple config trees with configurable strategies (`"override"` or `"merge"`).

## Registry

### `src/registry.nix`

Named module discovery and resolution. Builds the registry attrset from directory structure.

### `src/migrate.nix`

Registry rename detection. Scans for broken `registry.X.Y` references and suggests fixes.

### `src/analyze.nix`

Registry dependency graph analysis. Finds all registry references in source files.

### `src/visualize.nix`

Graph output generation. Produces HTML (D3.js) or JSON representations of dependency graph.

### `src/visualize-html.js`

JavaScript template for interactive HTML visualization.

## Flake Integration

### `src/flakeModule.nix`

Flake-parts integration module. Defines all `imp.*` options and wires up auto-loading.

### `src/collect-inputs.nix`

Collect `__inputs` declarations from files for flake.nix generation.

### `src/format-flake.nix`

Format and generate flake.nix content from collected inputs.

## Test Files

### `tests/default.nix`

Test runner entry point.

### `tests/core.nix`

Tests for core import functionality.

### `tests/tree.nix`

Tests for tree building.

### `tests/registry.nix`

Tests for registry functionality.

### `tests/migrate.nix`

Tests for migration detection.

### `tests/analyze.nix`

Tests for dependency analysis.

### `tests/imp.nix`

Integration tests for the full API.

### `tests/flake-file.nix`

Tests for flake.nix generation.

### `tests/fixtures/`

Test fixtures - example directory structures for tests.

## File Dependencies

```
default.nix
└── api.nix
    ├── lib.nix
    ├── collect.nix
    ├── tree.nix
    ├── configTree.nix
    ├── mergeConfigTrees.nix
    ├── registry.nix
    ├── migrate.nix
    ├── analyze.nix
    ├── visualize.nix
    └── collect-inputs.nix

flakeModule.nix
├── api.nix
├── registry.nix
├── collect-inputs.nix
└── format-flake.nix
```

## See Also

- [API Methods](./methods.md) - Method documentation
- [Module Options](./options.md) - Configuration options
