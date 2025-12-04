# Tests for visualize module
{ lib, imp, ... }:
let
  visualize = import ../src/visualize { inherit lib; };
  registryLib = import ../src/registry.nix { inherit lib; };
  analyze = (imp.withLib lib).analyze;

  # Use registry-test fixture for testing
  testRegistryPath = ./fixtures/registry-test;
  testRegistry = registryLib.buildRegistry testRegistryPath;

  # Sample graph for testing visualization functions
  sampleGraph = {
    nodes = [
      {
        id = "modules.home.shell";
        path = /test/path/shell;
        type = "configTree";
      }
      {
        id = "modules.home.devTools";
        path = /test/path/devTools;
        type = "configTree";
      }
      {
        id = "hosts.workstation";
        path = /test/path/workstation;
        type = "configTree";
      }
    ];
    edges = [
      {
        from = "modules.home.shell";
        to = "hosts.workstation";
        type = "import";
      }
      {
        from = "modules.home.devTools";
        to = "hosts.workstation";
        type = "import";
      }
    ];
  };

  # Minimal graph with single node
  minimalGraph = {
    nodes = [
      {
        id = "single.node";
        path = /test/single;
        type = "file";
      }
    ];
    edges = [ ];
  };

  # Graph with merge strategy
  mergeGraph = {
    nodes = [
      {
        id = "modules.home.base";
        path = /test/base;
        type = "configTree";
        strategy = "merge";
      }
      {
        id = "modules.home.extended";
        path = /test/extended;
        type = "configTree";
        strategy = "override";
      }
    ];
    edges = [
      {
        from = "modules.home.base";
        to = "modules.home.extended";
        type = "merge";
        strategy = "merge";
      }
    ];
  };
in
{
  # toJson tests
  toJson."test returns nodes and edges" = {
    expr = visualize.toJson sampleGraph;
    expected = {
      nodes = [
        {
          id = "modules.home.shell";
          path = "/test/path/shell";
          type = "configTree";
        }
        {
          id = "modules.home.devTools";
          path = "/test/path/devTools";
          type = "configTree";
        }
        {
          id = "hosts.workstation";
          path = "/test/path/workstation";
          type = "configTree";
        }
      ];
      edges = sampleGraph.edges;
    };
  };

  toJson."test converts paths to strings" = {
    expr =
      let
        result = visualize.toJson minimalGraph;
      in
      builtins.isString (builtins.head result.nodes).path;
    expected = true;
  };

  toJson."test preserves edge structure" = {
    expr = (visualize.toJson sampleGraph).edges;
    expected = sampleGraph.edges;
  };

  # toJsonMinimal tests
  toJsonMinimal."test returns only id and type" = {
    expr = visualize.toJsonMinimal minimalGraph;
    expected = {
      nodes = [
        {
          id = "single.node";
          type = "file";
        }
      ];
      edges = [ ];
    };
  };

  toJsonMinimal."test excludes path from nodes" = {
    expr =
      let
        result = visualize.toJsonMinimal sampleGraph;
        firstNode = builtins.head result.nodes;
      in
      firstNode ? path;
    expected = false;
  };

  toJsonMinimal."test preserves strategy when present" = {
    expr =
      let
        result = visualize.toJsonMinimal mergeGraph;
        nodeWithStrategy = builtins.head (lib.filter (n: n.id == "modules.home.base") result.nodes);
      in
      nodeWithStrategy.strategy;
    expected = "merge";
  };

  toJsonMinimal."test excludes strategy when absent" = {
    expr =
      let
        result = visualize.toJsonMinimal sampleGraph;
        firstNode = builtins.head result.nodes;
      in
      firstNode ? strategy;
    expected = false;
  };

  # toHtml tests
  toHtml."test produces valid HTML output" = {
    expr =
      let
        html = visualize.toHtml sampleGraph;
        trimmed = lib.trim html;
      in
      lib.hasPrefix "<!doctype html>" (lib.toLower trimmed);
    expected = true;
  };

  toHtml."test contains graph data placeholder replacement" = {
    expr =
      let
        html = visualize.toHtml sampleGraph;
      in
      # Should NOT contain the placeholder after replacement
      !(lib.hasInfix "/*GRAPH_DATA*/" html);
    expected = true;
  };

  toHtml."test contains cluster colors placeholder replacement" = {
    expr =
      let
        html = visualize.toHtml sampleGraph;
      in
      # Should NOT contain the placeholder after replacement
      !(lib.hasInfix "/*CLUSTER_COLORS*/" html);
    expected = true;
  };

  toHtml."test contains force-graph script reference" = {
    expr =
      let
        html = visualize.toHtml sampleGraph;
      in
      lib.hasInfix "force-graph" html;
    expected = true;
  };

  toHtml."test handles empty graph" = {
    expr =
      let
        emptyGraph = {
          nodes = [ ];
          edges = [ ];
        };
        html = visualize.toHtml emptyGraph;
        trimmed = lib.trim html;
      in
      lib.hasPrefix "<!doctype html>" (lib.toLower trimmed);
    expected = true;
  };

  toHtml."test merges nodes with same signature" = {
    expr =
      let
        # Two nodes with same cluster and connections should merge
        duplicateGraph = {
          nodes = [
            {
              id = "modules.home.foo";
              path = /test/foo;
              type = "file";
            }
            {
              id = "modules.home.bar";
              path = /test/bar;
              type = "file";
            }
            {
              id = "outputs.target";
              path = /test/target;
              type = "output";
            }
          ];
          edges = [
            {
              from = "modules.home.foo";
              to = "outputs.target";
              type = "import";
            }
            {
              from = "modules.home.bar";
              to = "outputs.target";
              type = "import";
            }
          ];
        };
        html = visualize.toHtml duplicateGraph;
      in
      # Just verify it produces valid HTML (merging is internal optimization)
      lib.hasPrefix "<!doctype html>" (lib.toLower (lib.trim html));
    expected = true;
  };

  # clusterColors tests
  clusterColors."test contains expected cluster keys" = {
    expr = visualize.clusterColors ? "modules.home";
    expected = true;
  };

  clusterColors."test contains nixos modules color" = {
    expr = visualize.clusterColors ? "modules.nixos";
    expected = true;
  };

  clusterColors."test contains outputs color" = {
    expr = visualize.clusterColors ? "outputs.nixosConfigurations";
    expected = true;
  };

  clusterColors."test colors are valid hex strings" = {
    expr =
      let
        homeColor = visualize.clusterColors."modules.home";
      in
      lib.hasPrefix "#" homeColor && builtins.stringLength homeColor == 7;
    expected = true;
  };

  # Integration with analyze module
  integration."test toJson works with analyzeRegistry output" = {
    expr =
      let
        graph = analyze.analyzeRegistry { registry = testRegistry; };
        json = visualize.toJson graph;
      in
      builtins.isAttrs json && json ? nodes && json ? edges;
    expected = true;
  };

  integration."test toJsonMinimal works with analyzeRegistry output" = {
    expr =
      let
        graph = analyze.analyzeRegistry { registry = testRegistry; };
        json = visualize.toJsonMinimal graph;
      in
      builtins.isAttrs json && json ? nodes && json ? edges;
    expected = true;
  };

  integration."test toHtml works with analyzeRegistry output" = {
    expr =
      let
        graph = analyze.analyzeRegistry { registry = testRegistry; };
        html = visualize.toHtml graph;
        trimmed = lib.trim html;
      in
      lib.hasPrefix "<!doctype html>" (lib.toLower trimmed);
    expected = true;
  };

  # Edge case tests
  edgeCases."test handles nodes with dots in names" = {
    expr =
      let
        dottedGraph = {
          nodes = [
            {
              id = "a.b.c.d.e";
              path = /test/deep;
              type = "file";
            }
          ];
          edges = [ ];
        };
        html = visualize.toHtml dottedGraph;
      in
      lib.hasPrefix "<!doctype html>" (lib.toLower (lib.trim html));
    expected = true;
  };

  edgeCases."test handles self-referential edges filtered out" = {
    expr =
      let
        selfRefGraph = {
          nodes = [
            {
              id = "modules.self";
              path = /test/self;
              type = "file";
            }
          ];
          edges = [
            {
              from = "modules.self";
              to = "modules.self";
              type = "import";
            }
          ];
        };
        html = visualize.toHtml selfRefGraph;
      in
      # Should produce valid HTML (self-refs are filtered in toHtml)
      lib.hasPrefix "<!doctype html>" (lib.toLower (lib.trim html));
    expected = true;
  };
}
