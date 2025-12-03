# File Reference

## Core

| File              | Purpose                       |
| ----------------- | ----------------------------- |
| `src/default.nix` | Entry point, exports main API |
| `src/api.nix`     | Chainable methods             |
| `src/lib.nix`     | Internal utilities            |

## Import & Collection

| File              | Purpose                                        |
| ----------------- | ---------------------------------------------- |
| `src/collect.nix` | File collection, filtering, naming conventions |
| `src/tree.nix`    | Directory to nested attrset conversion         |

## Config Trees

| File                       | Purpose                          |
| -------------------------- | -------------------------------- |
| `src/configTree.nix`       | Directory to option path mapping |
| `src/mergeConfigTrees.nix` | Multi-tree composition           |

## Registry

| File                    | Purpose                      |
| ----------------------- | ---------------------------- |
| `src/registry.nix`      | Named module discovery       |
| `src/migrate.nix`       | Broken reference detection   |
| `src/analyze.nix`       | Dependency graph analysis    |
| `src/visualize.nix`     | HTML/JSON graph output       |
| `src/visualize-html.js` | D3.js visualization template |

## Flake Integration

| File                     | Purpose                                     |
| ------------------------ | ------------------------------------------- |
| `src/flakeModule.nix`    | flake-parts module, defines `imp.*` options |
| `src/collect-inputs.nix` | `__inputs` collection                       |
| `src/format-flake.nix`   | flake.nix generation                        |

## Dependencies

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
