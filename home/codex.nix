# --- codex ---
# OpenAI Codex CLI is installed from npm into a private prefix. The prefix's
# bin stays off PATH, so the command is exposed through the versioned Home
# Manager wrapper below.
#
# Every Home Manager activation resolves npm's `latest` tag so Codex is updated
# whenever a newer release is available. The command pins the npmmirror registry
# because the huaweicloud mirror in ~/.npmrc is unreliable from this network.
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  prefix = "${config.home.homeDirectory}/.npm-global";
  npm = "${pkgs.nodejs_22}/bin/npm";

  # Upstream 0.159.2 bypasses the syntax theme for greeting accents and picker
  # fills. Translate only those fixed RGB colors at the terminal boundary so
  # npm updates remain available without maintaining a fork of Codex.
  colorFilter = pkgs.writeText "codex-colors.py" (builtins.readFile ../scripts/codex-colors.py);
  codexWrapper = pkgs.writeShellScriptBin "codex" ''
    exec ${pkgs.python3}/bin/python3 ${colorFilter} \
      --accent ${lib.escapeShellArg theme.accent} \
      --selection ${lib.escapeShellArg theme.accent-bg} \
      --selection-text ${lib.escapeShellArg theme.cursor} \
      -- ${pkgs.nodejs_22}/bin/node ${prefix}/bin/codex --config 'tui.theme="koru-fern"' "$@"
  '';

  # Codex highlights code blocks and diffs with a syntect theme and loads a
  # custom one from $CODEX_HOME/themes/<name>.tmTheme when [tui].theme names it.
  # Generate it from the shared palette so codex stays themed like every other
  # tool; the selection is injected by the wrapper below because config.toml is
  # rewritten by codex itself (project trust) and must stay user-owned.
  codexTheme = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key>
      <string>Koru Fern</string>
      <key>author</key>
      <string>Koru</string>
      <key>settings</key>
      <array>
        <dict>
          <key>scope</key>
          <string>codex.accent</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent}</string>
          </dict>
        </dict>
        <dict>
          <key>settings</key>
          <dict>
            <key>background</key>
            <string>${theme.bg}</string>
            <key>foreground</key>
            <string>${theme.fg}</string>
            <key>caret</key>
            <string>${theme.cursor}</string>
            <key>selection</key>
            <string>${theme.accent-bg}</string>
            <key>lineHighlight</key>
            <string>${theme.bg-alt}</string>
            <key>findHighlight</key>
            <string>${theme.ansi.yellow}</string>
            <key>inactiveSelection</key>
            <string>${theme.bg-alt}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>comment, punctuation.definition.comment</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.muted-alt}</string>
            <key>fontStyle</key>
            <string>italic</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>keyword, storage, storage.type, storage.modifier</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent-yellow}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>string, string.quoted, string.regexp, constant.character</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent-bright}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>constant.numeric, constant.language, constant.other</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.ansi.magenta}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>variable, variable.parameter, variable.other</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent-yellow-bright}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>entity.name.function, support.function, meta.function-call</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>entity.name.type, entity.name.class, entity.name.tag, support.type, support.class</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent-yellow}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>keyword.operator, punctuation, punctuation.separator</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.ansi.cyan}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>markup.inserted, diff.inserted</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent-bright}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>markup.deleted, diff.deleted</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.ansi-bright.red}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>markup.changed</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.accent-yellow}</string>
          </dict>
        </dict>
        <dict>
          <key>scope</key>
          <string>invalid, invalid.illegal</string>
          <key>settings</key>
          <dict>
            <key>foreground</key>
            <string>${theme.ansi.red}</string>
          </dict>
        </dict>
      </array>
    </dict>
    </plist>
  '';
in
{
  home.packages = [ codexWrapper ];

  home.file.".local/bin/codex".source = "${codexWrapper}/bin/codex";

  home.file.".codex/themes/koru-fern.tmTheme".text = codexTheme;

  # Codex's self-updater runs `npm install -g` without an explicit prefix.
  # Keep npm global installs in the writable user prefix instead of /nix/store.
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = prefix;
  };

  home.activation.installLatestCodex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    verboseEcho "Installing the latest @openai/codex into ${prefix}"
    run ${npm} install --global --prefix "${prefix}" \
      --registry https://registry.npmmirror.com \
      --include=optional --os=linux --cpu=x64 --libc=musl \
      --no-fund --no-audit \
      "@openai/codex@latest"
  '';
}
