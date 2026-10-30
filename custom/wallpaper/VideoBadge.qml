import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.custom.wallpaper

// The play icon that marks a video in the wallpaper pickers, as the old fork drew it.
// `path` is the wallpaper itself or the poster standing in for it.
MaterialIcon {
    required property string path

    visible: VideoWallpapers.isVideo(path) || VideoWallpapers.isPoster(path)
    opacity: 0.8
    text: "play_circle"
    color: Colours.palette.m3onSurface
    fontStyle: Tokens.font.icon.extraLarge
}
