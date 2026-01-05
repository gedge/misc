# misc

## g\_lib.sh

A shell (bash- and zsh-compatible) library, largely for:

- logging (with colours)
- easier input (e.g. with defaults, single-keystroke, continuation, etc)

Put the file on your `PATH` and then use `source g_lib.sh` in your shell.

### g\_lib usage

```shell
source g_lib.sh
g_opts ...

g_info ...
yorn ...
g_select ...
g_colr $colour $text
```

See source for what options are available.

- `g_colr [ -r ] $colour "text"`

  Example: `g_colr cyan "this is output in colour"`

  Output the *text* in *colour* - where *colour* is one of:

      - `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan` or `white`
      - for bold versions of the colours, use one of:
        - uppercase - e.g. `BLACK` is grey
        - the prefix `bright_` - e.g. `bright_black` is grey
      - `BOLD` turns on bold for the current colour
      - `${foreground_colour}_on_${background_colour}` - e.g. `black_on_white`

   If *text* already has embedded colours, then the `-r` flag can be used to re-apply
   *colour* after each embedded colour segment. e.g.
      `g_colr -r cyan "cyan-before $(g_colr red "red-highlight") cyan-after"`

- `yorn "Continue"`

  Ask a question and the single-keystroke answer (`y`, `n`) returns in `$yorn`

## src\_up.sh

A shell library for deploying files - e.g. using `diff`, `install` and prompting
(uses `g_lib.sh`, above).
Handles symlinks in a more verbose/clear manner.

### src\_up.sh usage

```shell
source src_up.sh
src_up { --0755 | --install | --lines | --ln $ln_to | --mkdir | --verbose } [ -- ] $src $target
```

## Licence

Copyright © 2018-2026, Geraint "Gedge" Edwards

Released under MIT license, see [LICENSE](LICENSE.md) for details.
