# Cipher

A terminal-styled Roblox UI library: boot sequence, CRT scanline, built-in command line,
flags, configs and six themes, all in one file (`Cipher.lua`).

```lua
local Cipher = loadstring(game:HttpGet("https://raw.githubusercontent.com/RedScaleR/Cypher/main/Cipher.lua"))()
```

## Quick start (the short way)

Every function takes plain arguments. A function argument is always the callback, and you can
leave out anything you don't need.

```lua
local Window = Cipher:Window("CIPHER")
local Main = Window:Tab("Main")

Main:Button("Say hi", function()
	print("hi")
end)

Main:Toggle("Fly", function(on)
	print("fly:", on)
end)

Main:Slider("Walk speed", 16, 200, 16, function(value)
	game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
end)

Main:Dropdown("Mode", { "Legit", "Rage" }, function(choice) print(choice) end)
Main:Input("Message", "type here...", function(text) print(text) end)
Main:Keybind("Dash", "Q", function() print("dash") end)
Main:ColorPicker("ESP colour", Color3.fromRGB(255, 0, 0), function(color) end)
Main:Label("Made with Cipher")

Window:Settings()   -- ready-made tab: theme, accent, keybinds, UI scale, configs
Cipher:Notify("Loaded", "Press RightShift to hide the menu", "success")
```

### Cheat sheet

| write this | arguments (in order) |
| --- | --- |
| `Cipher:Window(title)` | title |
| `Window:Tab(name, icon, description)` | icon and description are optional |
| `Tab:Section(name, side)` | side is `"Left"` or `"Right"` in two-column tabs |
| `Button(name, fn)` | |
| `Toggle(name, default, fn)` | `fn(on)` |
| `Slider(name, min, max, default, fn)` | `fn(value)` |
| `Dropdown(name, options, default, fn)` | a list as the default makes it multi-select; `"Players"` as the options lists players |
| `Input(name, placeholder, default, fn)` | `fn(text)` |
| `Keybind(name, key, fn)` | `fn(state)` |
| `ColorPicker(name, color, fn)` | `fn(color)`; color can be a `Color3` or `"#FF0000"` |
| `Label(text)` / `Paragraph(title, text)` / `Divider(text)` | |
| `Cipher:Notify(title, text, type, seconds)` | type: `"info"`, `"success"`, `"warning"`, `"error"` |

Elements can go straight on a tab or inside a section. Every element is returned, so you can keep it
and change it later:

```lua
local fly = Main:Toggle("Fly")
fly:Set(true)
print(fly.Value)
```

### Toggle add-ons

A toggle can carry its own keybind and colour picker, like most cheat menus:

```lua
local esp = Main:Toggle("ESP", function(on) end)
esp:AddKeybind("E")                  -- E turns ESP on / off
esp:AddKeybind("R", "Hold")          -- or: only on while R is held
esp:AddColorPicker(Color3.new(1, 0, 0), function(color) end)
```

## The full way (option tables)

Everything above also accepts a table, which unlocks every option. Use it when you need flags,
descriptions, tooltips and so on.

```lua
local Window = Cipher:CreateWindow({
	Title = "CIPHER",
	Subtitle = "demo",
	Size = { 820, 520 },
	Theme = "Matrix",           -- Matrix, Amber, Cyber, Blood, Phantom, Ghost
	ToggleKey = "RightShift",   -- false disables it
	AutoLoadConfig = true,      -- load the config marked as autoload
})

local Combat = Window:AddTab({ Name = "Combat", Icon = ">", Columns = 2 })
local Aim = Combat:AddSection({ Name = "aim", Side = "Left" })

Aim:AddToggle({
	Name = "Enabled",
	Description = "master switch",
	Flag = "aim_enabled",
	Default = false,
	Tooltip = "turns the aimbot on",
	Callback = function(on) end,
})
```

Every element with a `Flag` is readable at any time through `Cipher.Flags.<flag>` (its value) and
`Cipher.Options.<flag>` (the element), and is saved in configs.

### Window options

| option | default | notes |
| --- | --- | --- |
| `Title` / `Name` | `"CIPHER"` | re-running a script with the same title replaces the old window |
| `Subtitle` | `"v<version>"` | |
| `Size` | `{660, 450}` | table, `Vector2` or `UDim2` (offsets); minimum 500x320 |
| `Theme` | `"Matrix"` | theme name or a colour table |
| `ToggleKey` | `RightShift` | `Enum.KeyCode`, a name like `"F"`, or `false` |
| `AutoLoadConfig` | `false` | loads the autoload config; elements created afterwards pick up their saved values |
| `IgnoreGameProcessed` | `false` | keybinds ignore input Roblox already used (menus, the game's own binds); the menu key still works |
| `ConfirmClose` | `true` | ask before the close button unloads everything |
| `ConfigFolder` | `"Cipher"` | where configs are written |
| `BootSequence` / `BootLines` | `true` / built-in | set `false` to skip, or pass your own lines |
| `Scanline` | `true` | the sweeping CRT line |
| `MobileButton` | auto | a draggable `>_` toggle button; on by default on touch-only devices |

Window methods: `Toggle`, `SetVisible`, `SetMinimized`, `SetSize`, `SetScale`, `Center`, `SetTitle`,
`SetSubtitle`, `SetToggleKey`, `SetScanline`, `SetKeybindList`, `Tab` / `AddTab`, `GetTab`,
`SelectTab`, `RemoveTab`, `Dialog`, `Notify`, `ToggleTerminal`, `Log`, `AddCommand`, `RunCommand`,
`Settings` / `AddSettingsTab`, `OnDestroy`, `Destroy`.

### Two-column tabs

`Window:AddTab({ Name = "Combat", Columns = 2 })` puts sections side by side. Sections alternate
left and right unless you pass `Side`. Two columns need a window at least about 760 wide; on
narrower windows they stack into one column automatically.

### Element options

Every element accepts `Name`, `Description`, `Flag`, `Callback`, `Tooltip`, `Locked` (`true` or a
reason string), `Visible` and `IgnoreConfig`.

| element | extra options |
| --- | --- |
| `Button` | `Confirm` (click twice) |
| `Toggle` | `Default` |
| `Slider` | `Min`, `Max` (or `Range = {min, max}`), `Increment`, `Default`, `Suffix` |
| `Dropdown` | `Options`, `Default`, `Multi`, `Search`, `MaxVisible`, `AllowNone`, `PlayerList`, `IncludeSelf` |
| `Input` / `Textbox` | `Default`, `Placeholder`, `Numeric`, `Finished` (fire on focus lost, default `true`), `MaxLength`, `Width`, `ClearOnFocus`, `ClearOnEnter`, `OnEnter` |
| `Keybind` | `Default`, `Mode` (`"Toggle"`, `"Hold"`, `"Press"`), `ChangedCallback(key)`; `Callback(state)` |
| `ColorPicker` | `Default` (Color3 or hex), `Rainbow`, `RainbowSpeed` |
| `Label` | `Text`, `Color` (Color3 or theme key), `Align`, `TextSize`, `RichText` |
| `Paragraph` | `Title`, `Content`, `RichText` |
| `Divider` | `Text` |
| `Console` | `Lines`, `MaxLines`, `Timestamps`; `:Log(text, kind)`, `:Info`, `:Success`, `:Warn`, `:Error`, `:Debug`, `:Clear` |

Shared element methods: `Set(value, silent)`, `OnChanged(fn)`, `SetTitle`, `SetDescription`,
`SetVisible`, `Lock(reason)`, `Unlock`, `Destroy`. Dropdowns also have `Refresh(options, keepValue)`,
`Add`, `Remove`, `Clear`, `Open`, `Close`. Sliders have `SetRange`, `SetMin`, `SetMax`,
`SetIncrement` and `SetSuffix`. Tabs have `Destroy()`.

## Search

The `/` box in the sidebar searches every tab at once. Tabs show how many matches they have, and
tabs with none are dimmed.

## Notifications and dialogs

```lua
local n = Cipher:Notify({
	Title = "update",
	Content = "a new version is out",
	Type = "info",           -- info, success, warning, error
	Duration = 5,            -- 0 or less stays until dismissed
	Actions = { { Name = "open", Callback = function() end } },
})
n:SetContent("downloading...")

Window:Dialog({
	Title = "reset settings",
	Content = "This cannot be undone.",
	Buttons = { { Name = "reset", Primary = true, Callback = function() end }, { Name = "cancel" } },
})
```

## Terminal

Open it with the `>_` button or `Window:ToggleTerminal()`. Built-in commands: `help`, `clear`,
`echo`, `tabs`, `tab`, `flags`, `get`, `set`, `toggle`, `theme`, `config`, `notify`, `stats`,
`rejoin`, `hide`, `exit`. Tab completes and Up/Down walk the history.

```lua
Window:AddCommand("speed", "set walk speed", function(args, console)
	console:Success("speed -> " .. tostring(tonumber(args[1])))
end)
```

## Themes and configs

```lua
Cipher:SetTheme("Cyber")
Cipher:SetAccent("#FF2D96")
Cipher:AddTheme("Mint", { Accent = Color3.fromRGB(80, 255, 200) })  -- missing keys fall back to Matrix
local conn = Cipher:OnThemeChanged(function(name, theme) end)
conn:Disconnect()

Cipher:SaveConfig("legit")   -- flags, theme, accent, and each window's menu key + UI scale
Cipher:LoadConfig("legit")
Cipher:ListConfigs()
Cipher:SetAutoload("legit")  -- then CreateWindow({ AutoLoadConfig = true }) loads it
```

Configs need `writefile`, `readfile` and `isfile` from the executor; `Cipher:HasFileSystem()`
tells you whether they are available.

`Cipher:Unload()` destroys every window and disconnects everything. Use `Cipher:OnUnload(fn)` to
switch your features off when that happens.

## Development

GitHub Actions runs `.github/workflows/check.yml` on every push and pull request. It checks that
`Cipher.lua` compiles with `luau-compile` and lints it with
[selene](https://github.com/Kampfkarren/selene) (`selene.toml`, `cipher.yml`).

## Changelog

### 1.1.0

New:
- **Short style everywhere:** `Main:Button("Hi", fn)`, `Main:Toggle("Fly", fn)`,
  `Main:Slider("Speed", 16, 200, 16, fn)`, `Cipher:Window("TITLE")`, `Window:Tab("Main")`,
  `Tab:Section("combat")`, `Window:Settings()` and `Cipher:Notify(title, text, type)`.
  Option tables still work exactly as before.
- Toggle add-ons: `toggle:AddKeybind(key, mode)` and `toggle:AddColorPicker(color, fn)`.
- Two-column tabs (`Columns = 2`, `Side = "Left" | "Right"`) that stack on narrow windows.
- Search covers every tab and shows hit counts in the sidebar.
- `AutoLoadConfig` window option; configs also save each window's menu key and UI scale.
- `IgnoreGameProcessed` window option.
- `Window:RemoveTab` / `Tab:Destroy`.
- Rainbow colours update about 20 times a second instead of every frame.
- The notification overlay is removed once no windows are left (e.g. after re-running a script).
- Themes added with `AddTheme` appear in the settings tab's dropdown.
- `Cipher:OnThemeChanged` returns a handle with `:Disconnect()`.
- Configs save and restore the custom accent colour.

Breaking:
- `tab.Button` (the sidebar button) is now `tab.TabButton`, because `tab:Button(...)` creates buttons.

Fixes:
- The colour picker reads the pointer in screen coordinates (it could be offset by the top bar height).
- Keybinds: binding right-click while hovering the row no longer clears the new bind instantly,
  clicking the row again now cancels listening, and changing the key or mode of an active bind
  releases it.
- Dialogs and the terminal un-minimize the window instead of opening invisibly.
- The window can no longer be dragged off-screen, stays on screen when the viewport changes,
  and centres using the auto-scaled height, so the topbar is no longer cut off on small screens.
- Destroying a Slider, ColorPicker or player-list Dropdown now disconnects its input and player listeners.
- Theme changes only touch colours that changed, and the keybind list rebuilds at most once per frame.
- The ColorPicker keeps its hue when set to a grey.
- `set` in the terminal reports invalid values instead of claiming success.
- Looping window tweens are cancelled on destroy.
