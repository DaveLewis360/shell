pragma Singleton

import Quickshell

// [fork] The environment for programs the shell starts.
//
// shell-restart may give the shell a few variables meant only for the shell itself:
// LIBVA_DRIVER_NAME=iHD and QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi, so the video
// wallpaper is decoded by the Intel iGPU instead of the CPU or the NVIDIA card. A
// program the shell starts would inherit them, so shell-restart also passes the
// session's own values in CAELESTIA_CHILD_ENV, a JSON object (null = not set), and
// every launch point hands `env` to the child: apps get the session environment back.
//
// Without CAELESTIA_CHILD_ENV (the shell was started some other way, with nothing
// overridden) `env` changes nothing.
Singleton {
    readonly property var env: {
        const out = {};
        const raw = Quickshell.env("CAELESTIA_CHILD_ENV");
        if (raw) {
            try {
                const parsed = JSON.parse(raw);
                if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                    for (const key of Object.keys(parsed)) {
                        const value = parsed[key];
                        if (value === null || typeof value === "string")
                            out[key] = value;
                    }
                }
            } catch (e) {
                console.warn(`ChildEnv: CAELESTIA_CHILD_ENV is not JSON (${e}), programs inherit the shell's environment`);
            }
        }
        out.CAELESTIA_CHILD_ENV = null;
        return out;
    }

    // Quickshell.execDetached with the session environment; workingDirectory is optional
    function exec(command: var, workingDirectory: var): void {
        const context = {
            command,
            environment: env
        };
        if (workingDirectory)
            context.workingDirectory = workingDirectory;
        Quickshell.execDetached(context);
    }
}
