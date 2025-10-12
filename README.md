# misc

## g\_lib.sh

A shell (bash- and zsh-compatible) library, largely for:

- logging (with colours)
- easier input (e.g. with defaults, single-keystroke, continuation, etc)

Put the file on your `PATH` and then use `source g_lib.sh` in your shell.

### g\_lib usage

- `source g_lib.sh`
- `g_opts ...`

  See source for what options are available.

- `g_colr [ -r ] $colour "text"`

  Example: `g_colr cyan "this is output in colour"`

  Output the *text* in *colour* - where *colour* is one of:

      - `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan` or `white`
      - uppercase versions of the above indicate the bold version - e.g. `BLACK` is grey
      - `BOLD` turns on bold for the current colour
      - `${foreground_colour}_on_${background_colour}` - e.g. `black_on_white`

   If *text* already has embedded colours, then the `-r` flag can be used to re-apply
   *colour* after each embedded colour segment. e.g.
      `g_colr -r cyan "cyan-before $(g_colr red "red-highlight") cyan-after"`

- `yorn "Continue"`

  Ask a question and the single-keystroke answer (`y`, `n`) returns in `$yorn`

## Licence

Copyright © 2018-2025, Geraint "Gedge" Edwards

Released under MIT license, see [LICENSE](LICENSE.md) for details.
