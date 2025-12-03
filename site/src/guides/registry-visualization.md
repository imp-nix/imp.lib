# Registry Visualization

Generate an interactive graph showing how modules reference each other through the registry.

## Generating Visualization

```sh
# Generate interactive HTML
nix run .#imp-vis > deps.html

# Or output as JSON
nix run .#imp-vis -- --format=json > deps.json
```

Open `deps.html` in a browser to explore your module dependency graph.

## What You See

- **Nodes** represent registry entries (modules, hosts, users, etc.)
- **Edges** show `registry.X.Y` references between modules
- **Colors** indicate clusters (e.g., `modules.home`, `hosts`, `outputs`)
- **Sink nodes** (final outputs like `nixosConfigurations`) are larger with labels
- **Animated dashed edges** show dependency direction

## Interaction

- **Hover** over nodes to highlight connections
- **Drag** nodes to reposition (positions become fixed)
- **Scroll** to zoom in/out
- **Click** empty space to pan

## Node Merging

Nodes with identical edge topology are merged to reduce clutter. For example, if multiple features all flow to the same outputs, they appear as a single grouped node.

## Standalone Usage

The visualize tool works with any directory:

```sh
nix run .#visualize -- ./path/to/nix > deps.html
```

## JSON Format

For programmatic analysis:

```sh
nix run .#imp-vis -- --format=json
```

Output structure:

```json
{
  "nodes": [
    { "id": "hosts.server", "cluster": "hosts" },
    { "id": "modules.nixos.base", "cluster": "modules.nixos" }
  ],
  "edges": [
    { "from": "hosts.server", "to": "modules.nixos.base" }
  ]
}
```

## Use Cases

- **Understanding dependencies** - See which modules depend on what
- **Identifying cycles** - Spot circular dependencies
- **Refactoring planning** - Understand impact of changes
- **Documentation** - Visual overview of module structure
- **Onboarding** - Help new contributors understand the codebase

## Example Graph

A typical NixOS config might show:

```
nixosConfigurations.server
  └── hosts.server
      ├── modules.nixos.base
      │   └── modules.nixos.hardware
      ├── modules.nixos.features.networking
      └── users.alice
          └── modules.home.features.shell
```

## Customization

The HTML output uses D3.js for rendering. You can modify the generated file to:

- Change colors
- Adjust layout parameters
- Add custom styling
- Filter displayed nodes

## See Also

- [The Registry](../concepts/registry.md) - Registry overview
- [Registry Migration](./registry-migration.md) - Fix broken references
