# custom/

Everything in this directory belongs to the fork. Upstream never touches it, so
it cannot conflict when the fork is rebased onto a new release.

The fork's options live under `fork` in `shell.json`, declared in
`plugin/src/Caelestia/Config/forkconfig.hpp` and read from QML as
`GlobalConfig.fork.*`:

- `fork.bar.horizontal`: the bar along the top edge;
- `fork.bar.showNumLock`: the Num Lock icon of the lock keys status entry.

The bar centre is not an option of its own: it is upstream's `bar.entries`, which
the Nexus row edits.

- `bar/` holds the top bar (`HBar`) and horizontal ports of the upstream bar
  components. Each port follows one upstream file; `bar/VENDORED.json` lists the
  file and the blob it was ported from, so upstream changes can be carried over.
  `bar/MiniDash.qml` is the fork's own `miniDash` bar entry.
- `nexus/` holds the settings rows the fork adds to upstream's Nexus pages.
- `media/` holds `CoverArtCache`, which the cover art widgets read.
- Upstream files only carry small hooks that point here, each marked `[fork]`:

  ```sh
  git grep -n '\[fork\]'
  ```

The vertical bar is untouched upstream code. When something looks wrong, turning
the option off shows whether the fork or upstream is at fault.
