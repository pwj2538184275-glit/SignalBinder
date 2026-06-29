# SignalBinder

> **[中文文档](README_ZH.md)** — 查看中文版

A visual signal binding editor for Godot 4. Configure signal-to-method connections through the inspector and dock panel — no hand-written glue code required.

## Installation

1. Copy `addons/SignalBinder` into your project's `addons/` directory
2. Enable `SignalBinder` in **Project Settings → Plugins**
3. The **IO Binding Table** dock panel will appear in the editor main screen

## Quick Start

1. Add an `IoBinder` node to your scene
2. Set `signal_owner` — the node that emits signals (defaults to the parent node if left empty)
3. Add entries to `iosets` and pick a binding type
4. Set `signal_name` (which signal to listen for) and `method_name` (which method to call)
5. Run the scene

> In the inspector, `signal_name` and `method_name` use dropdown menus populated from the actual signal and method lists of the target objects — no manual typing needed.

## Signal Source (IoSignalSource)

Each binding uses `IoBinder.signal_owner` as the signal source by default.
To have a specific binding listen to a different node, set a custom `signal_source`:

| Type | Description |
|------|-------------|
| `PARENT` | Use the IoBinder's `signal_owner` (default) |
| `NODE_PATH` | Use a node path relative to the IoBinder |
| `AUTOLOAD` | Use an autoloaded singleton as the signal source |

When set, the inspector dropdown for `signal_name` automatically reads signals from the specified source.

## Binding Types

| Type | Class | Description |
|------|-------|-------------|
| **Path** | `IoBindPath` | Call a method on a node resolved by `NodePath` |
| **Group** | `IoBindGroup` | Call a method on all nodes in a scene group |
| **Script Singleton** | `IoBindSingleton` | Call a **static** method on a script file |
| **Global Autoload** | `IoBindGlobal` | Call an **instance** method on an autoloaded singleton |
| **Self** | `IoBindSelf` | Call a method on the signal owner itself |

> `IoBindGlobal` uses `Engine.get_singleton()` to get the autoload instance and calls an instance method on it.
> `IoBindSingleton` calls a static method on the script. They serve different use cases.

## Common Properties (IoBindBase)

All binding types share these properties:

| Property | Type | Description |
|----------|------|-------------|
| `signal_source` | IoSignalSource | Optional per-binding signal source (empty = use IoBinder's signal_owner) |
| `signal_name` | String | Signal to listen for (inspector dropdown) |
| `method_name` | String | Method to call (inspector dropdown) |
| `parameters` | Array | Static parameter values configured in the editor |
| `param_mode` | Enum | How to combine static and signal parameters |
| `delay` | float | Delay in seconds before execution (0 = immediate) |
| `fire_once` | bool | Disconnect after the first trigger |
| `condition_method` | String | Optional condition: this method is called before execution; skip if it returns `false` |
| `debug` | bool | Print `[IoBind]` call log to the console when triggered |

### ParamMode

```
STATIC_ONLY     → Static parameters only
SIGNAL_ONLY     → Signal parameters only
APPEND_SIGNAL   → Static parameters + signal parameters appended
PREPEND_SIGNAL  → Signal parameters + static parameters prepended
```

## IoBindMulti (Multi-Binding)

`IoBindMulti` is a Node that manages multiple independent binding groups at runtime.
Each group is defined by an `IoBindMultiConfig` resource, specifying its own signal source path and IO configuration list.

Useful for UI lists, dynamically generated nodes, and similar scenarios.

## Editor Panel (IO Binding Table)

The **IO Binding Table** dock panel in the main editor screen provides:

- **Listing** — Shows all `IoBinder` and `IoBindMulti` nodes in the current scene
- **Collapse/Expand** — Toggle all binding entries with one click
- **Node Navigation** — Click a node name to select and focus it in the scene tree
- **Resource Editing** — Click the edit button to open an `IoBindBase` resource directly in the inspector
- **Refresh** — Manual refresh of the list
- **Recursion Toggle** — `SignalBinder/params/recursion` project setting controls recursive search

Each entry displays the signal source node, signal name, binding type, and target.

## Validation

The `IoBinder` node has a **"检测连接" (Validate Connections)** tool button in the inspector (editor-only). It checks:
- Whether `signal_owner` is valid
- Whether the signal exists on the signal source
- Whether the method exists on the target
- Whether node paths can be resolved
- Whether group members have the target method

## Inspector Dropdowns

`IoBindBase` and `IoSignalSource` are automatically enhanced in the inspector:

- **signal_name** — Dropdown populated from the signal source's signals (with argument preview)
- **method_name** — Dropdown populated from the target's methods (filtered, deduplicated, sorted)
- **target_autoload / autoload_name** — Dropdown listing all autoloads in the project
- Auto-selects the first item when the current value is empty
- Refreshes signal list automatically when `signal_source` changes

## Project Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `SignalBinder/params/show_full_params` | bool | false | Show full parameter names in dropdowns |
| `SignalBinder/params/recursion` | bool | false | Recursively search for IoBinder nodes in the dock panel |

## File Structure

```
addons/SignalBinder/
├── plugin.cfg                 # Plugin metadata
├── plugin.gd                  # EditorPlugin entry point
├── README.md
├── data/
│   ├── io_bind_base.gd        # IoBindBase abstract base class
│   ├── io_bind_path.gd        # IoBindPath (NodePath target)
│   ├── io_bind_group.gd       # IoBindGroup (group target)
│   ├── io_bind_singleton.gd   # IoBindSingleton (static method)
│   ├── io_bind_global.gd      # IoBindGlobal (autoload instance)
│   ├── io_bind_self.gd        # IoBindSelf (signal owner)
│   ├── io_signal_source.gd    # IoSignalSource (per-binding signal source)
│   ├── io_binder.gd           # IoBinder (main node)
│   ├── io_bind_multi.gd       # IoBindMulti (multi-binding node)
│   ├── io_bind_multi_config.gd# IoBindMultiConfig (multi-binding config)
│   └── io_bind_executor.gd    # IoBindExecutor (runtime connection manager)
└── inspector/
    ├── io_bind_inspector.gd   # EditorInspectorPlugin (dropdown enhancements)
    ├── io_bind_dock.gd        # Dock panel logic
    ├── io_bind_dock.tscn      # Dock panel scene
    ├── io_connection.gd       # Single binding entry control
    ├── io_connection.tscn     # Single binding entry scene
    ├── io_show.gd             # IoBinder/IoBindMulti display control
    └── io_show.tscn           # Display control scene
```

## License

MIT
