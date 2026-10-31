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
- `wallpaper/` holds video wallpapers. The caelestia CLI sets a video like an image
  (`caelestia wallpaper -f clip.mp4`); `VideoWallpapers` makes a poster frame for
  every video with ffmpeg and hands it to everything that needs an image,
  `VideoLayer` plays the video over it on the background, and `VideoBadge` marks
  videos in the pickers. The background plays a copy made for the screen by
  `video-native.sh` (H.264 that just covers the panel, at most 30 fps), cached
  under `~/.cache/caelestia/wallpaper/video-native/`, never the original; the
  poster shows until the copy exists or if it fails. Its behaviour switches (pause on battery or under a
  fullscreen window, unload instead of pause, the launcher preview delay) are
  constants at the top of `VideoWallpapers.qml`, not `shell.json` options yet.
  Upstream is building its own video wallpapers (`feat/video-wallpapers`); once
  that lands, this directory and its hooks go.
  Decoding: `shell-restart` (dotfiles) starts the shell with
  `QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi` and `LIBVA_DRIVER_NAME=iHD`, so the
  Intel iGPU decodes the copy (VA-API) and the NVIDIA card stays idle; if VA-API
  does not come up, Qt decodes in software, never on the NVIDIA card.
- `env/ChildEnv.qml` gives programs the shell starts the session's environment
  back: the two variables above are for the shell only. `shell-restart` passes the
  session values in `CAELESTIA_CHILD_ENV` (JSON, `null` = not set), and the launch
  points (launcher apps and actions, session menu, idle actions, calculator,
  recordings, swappy, `caelestia record`) hand `ChildEnv.env` to the child.
  Background helpers (`nmcli`, `hyprctl`, the caelestia CLI's wallpaper and scheme
  commands) still inherit the shell's environment; none of them uses VA-API.
- Upstream files only carry small hooks that point here, each marked `[fork]`:

  ```sh
  git grep -n '\[fork\]'
  ```

The vertical bar is untouched upstream code. When something looks wrong, turning
the option off shows whether the fork or upstream is at fault.
