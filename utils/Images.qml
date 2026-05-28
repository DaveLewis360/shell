pragma Singleton

import Quickshell

Singleton {
    readonly property list<string> validImageTypes: ["jpeg", "png", "webp", "tiff", "svg"]
    readonly property list<string> validImageExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg"]
    readonly property list<string> validVideoExtensions: ["mp4", "webm", "mkv", "mov", "gif"]
    readonly property list<string> validMediaExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg", "mp4", "webm", "mkv", "mov", "gif"]

    function isValidImageByName(name: string): bool {
        return validImageExtensions.some(t => name.endsWith(`.${t}`));
    }

    function isVideoByName(name: string): bool {
        return validVideoExtensions.some(t => name.endsWith(`.${t}`));
    }

    function isMediaByName(name: string): bool {
        return validMediaExtensions.some(t => name.endsWith(`.${t}`));
    }
}
