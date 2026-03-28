<div align="center">
  <svg xmlns="http://www.w3.org/2000/svg" width="577" height="324" viewBox="0 0 577 324">
    <defs>
      <linearGradient id="flareGradient" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#6464ff" />
        <stop offset="100%" stop-color="#c864ff" />
      </linearGradient>
    </defs>
    <rect width="100%" height="100%" fill="transparent" />
    <text x="32" y="50" font-family="ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace" font-size="18" line-height="22" xml:space="preserve" fill="#A0A0A0"><tspan x="32" dy="0"> ▄▄▄  ▄▄   ▄▄ ▄▄▄▄▄  ▄▄▄▄  ▄▄▄  ▄▄   ▄▄ ▄▄▄▄▄ </tspan><tspan x="32" dy="22">██▀██ ██ ▄ ██ ██▄▄  ███▄▄ ██▀██ ██▀▄▀██ ██▄▄  </tspan><tspan x="32" dy="22">██▀██  ▀█▀█▀  ██▄▄▄ ▄▄██▀ ▀███▀ ██   ██ ██▄▄▄ </tspan></text>
    <text x="32" y="136" font-family="ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace" font-size="18" line-height="22" xml:space="preserve" fill="url(#flareGradient)"><tspan x="32" dy="0">.-:::::&#x27;:::      :::.    :::::::..  .,::::::  </tspan><tspan x="32" dy="22">;;;&#x27;&#x27;&#x27;&#x27; ;;;      ;;`;;   ;;;;``;;;; ;;;;&#x27;&#x27;&#x27;&#x27;  </tspan><tspan x="32" dy="22">[[[,,== [[[     ,[[ &#x27;[[,  [[[,/[[[&#x27;  [[cccc   </tspan><tspan x="32" dy="22">`$$$&quot;`` $$&#x27;    c$$$cc$$$c $$$$$$c    $$&quot;&quot;&quot;&quot;   </tspan><tspan x="32" dy="22"> 888   o88oo,.__888   888,888b &quot;88bo,888oo,__ </tspan><tspan x="32" dy="22"> &quot;MM,  &quot;&quot;&quot;&quot;YUMMMYMM   &quot;&quot;` MMMM   &quot;W&quot; &quot;&quot;&quot;&quot;YUMMM</tspan></text>
    <text x="32" y="292" font-family="ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, monospace" font-size="18" line-height="22" xml:space="preserve" fill="#A0A0A0"><tspan x="32" dy="0">Community Plugins, Scripts and Docs for Flare</tspan></text>
  </svg>
</div>


This repository contains a curated catalog of plugins for [flare](https://github.com/gitanelyon/flare), a terminal-first Linux application launcher built with Rust + Ratatui.

## What is here

- `scripts/`: plugin scripts used by Flare (`*.sh`, `*.pl`, `*.py`, etc.).
- `API.md`: script protocol reference (`f!` directives, actions, output format).
- `DOCS.md`: installation, aliases, and authoring guide.

## Included scripts

- `battery.sh`
- `bluetooth.sh`
- `brightness.sh`
- `calculator.sh`
- `clipboard.sh`
- `help.sh`
- `runner.sh`
- `sudo.sh`
- `symbols.sh`
- `symbols.pl`
- `volume.sh`

## Install locally

```bash
mkdir -p ~/.config/flare/scripts
cp -r scripts/* ~/.config/flare/scripts/
chmod +x ~/.config/flare/scripts/*
```

Optional aliases can be defined in `~/.config/flare/alias.toml`.

If you use extension-based keys (`.sh`, `.pl`, etc.), quote them in TOML:

```toml
[scripts]
"volume.sh" = "v!"
battery = ":"
"clipboard.sh" = "+"
"symbols.pl" = "sym!"

[apps]
# You can also set app aliases!
"btop++" = "alacritty -e btop"
```

Unquoted dotted keys also work, but they are interpreted as TOML dotted paths.

For protocol details, see [API.md](API.md).
