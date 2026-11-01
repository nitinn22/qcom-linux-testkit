# Multimedia Sample Apps — GStreamer Sample Applications Test Suite

## Overview

Comprehensive validation suite for GStreamer multimedia sample applications across four categories: **Audio**, **Video**, **Display**, and **Camera**.

**Build Configuration Dependent:**
- **Config1 (Upstream)**: 16 apps total (2 audio + 7 video + 7 camera + 0 display)
- **Config2 (CAMX/Downstream)**: 33 apps total (2 audio + 10 video + 20 camera + 1 display)

The test suite automatically detects the build configuration based on `qtiqmmfsrc` plugin availability and runs the appropriate set of sample applications.

---

## Quick Start

```bash
# Run all sample apps (auto-detects config: 16 or 33 apps)
./run.sh

# Run specific category
./run.sh --category audio      # 2 apps
./run.sh --category video      # 7 or 10 apps
./run.sh --category camera     # 7 or 20 apps
./run.sh --category display    # 0 or 1 app

# Run specific app
./run.sh --app gst-video-playback-example

# Run with custom timeout
./run.sh --category video --timeout 60
```

---

## Sample Applications by Category

### Build Configuration Detection

The test suite automatically detects the build configuration:
- **Config1 (Upstream)**: `qtiqmmfsrc` plugin NOT available
- **Config2 (CAMX/Downstream)**: `qtiqmmfsrc` plugin available

### Config1 (Upstream) — 16 Apps Total

#### 🔊 Audio (2 apps)
- gst-audio-encode-example
- gst-audio-decode-example

#### 🎬 Video (7 apps)
- gst-concurrent-videoplay-composition
- gst-concurrent-videoplay-composition.py
- gst-videocodec-concurrent-playback
- gst-audio-video-playback
- gst-video-transcode-example
- gst-video-playback-example
- gst-opencv-transform.py

#### 📷 Camera (7 apps)
- gst-camera-single-stream-example
- gst-appsink-example
- gst-transform-example
- gst-camera-opencv-resize.py
- GstD-camera-single-stream-example
- gst-camera-encode.py
- gst-camera-rotate-downscale-file.py

#### 🖥️ Display (0 apps)
- None (gst-weston-composition-example is Config2 only)

### Config2 (CAMX/Downstream) — 33 Apps Total

#### 🔊 Audio (2 apps)
- gst-audio-encode-example
- gst-audio-decode-example

#### 🎬 Video (10 apps)
**Common (7 apps):**
- gst-concurrent-videoplay-composition
- gst-concurrent-videoplay-composition.py
- gst-videocodec-concurrent-playback
- gst-audio-video-playback
- gst-video-transcode-example
- gst-video-playback-example
- gst-opencv-transform.py

**Config2 only (3 apps):**
- gst-smartcodec-example
- gst-audio-video-encode
- gst-ai-smartcodec-example

#### 📷 Camera (20 apps)
**Common (7 apps):**
- gst-camera-single-stream-example
- gst-appsink-example
- gst-transform-example
- gst-camera-opencv-resize.py
- GstD-camera-single-stream-example
- gst-camera-encode.py
- gst-camera-rotate-downscale-file.py

**Config2 only (13 apps - require qtiqmmfsrc):**
- gst-multi-camera-example
- gst-multi-stream-example
- gst-snapshot-stream-example
- gst-activate-deactivate-streams-runtime-example
- gst-add-remove-streams-runtime
- gst-camera-metadata-example
- gst-add-streams-as-bundle-example
- gst-camera-burst-capture-example
- gst-camera-switch-example
- gst-camera-shdr-ldc-eis-example
- gst-multi-camera-stream-example.py
- gst-jpg-image-decode.py
- gst-jpg-decode-example

#### 🖥️ Display (1 app)
**Config2 only:**
- gst-weston-composition-example

---

## Prerequisites

### Required Tools
- `gst-launch-1.0` - GStreamer command-line tool
- `gst-inspect-1.0` - GStreamer plugin inspector
- Sample apps installed in `/usr/bin/`

### Required Plugins
- GStreamer core plugins
- GStreamer good plugins
- GStreamer bad plugins (for some apps)
- Hardware codec plugins (v4l2, etc.)
- waylandsink (for display apps)
- qtiqmmfsrc (for Config2 camera apps)

### Hardware/Environment
- Camera hardware (for camera apps)
- Display hardware (for display apps)
- Weston/Wayland (for display apps)

---

## Usage

```bash
./run.sh [OPTIONS]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--category <name>` | Run specific category (audio, video, display, camera, all) | all |
| `--app <name>` | Run specific sample app only | - |
| `--timeout <seconds>` | Timeout per app (apps terminated with SIGINT) | 30 |
| `--gst-debug <level>` | GStreamer debug level (1-9) | 2 |
| `--lava-testcase-id <name>` | Override test case name for LAVA reporting | - |
| `-h, --help` | Display help message | - |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SAMPLE_APP_TIMEOUT` | Timeout per app (seconds) | 30 |
| `SAMPLE_APP_GST_DEBUG` | GStreamer debug level | 2 |
| `GST_DEBUG_LEVEL` | Alternative to SAMPLE_APP_GST_DEBUG | 2 |

---

## Examples

```bash
# Run all sample apps (auto-detects config: 16 or 33 apps)
./run.sh

# Run specific category
./run.sh --category audio
./run.sh --category video
./run.sh --category camera
./run.sh --category display

# Run specific app
./run.sh --app gst-video-playback-example

# Run with custom timeout
./run.sh --category video --timeout 60

# Run specific app with custom timeout and debug
./run.sh --app gst-audio-video-playback --timeout 45 --gst-debug 5

# Using environment variables
export SAMPLE_APP_TIMEOUT=60
export SAMPLE_APP_GST_DEBUG=3
./run.sh --category camera
```

---

## Output

### Result Files
- `Multimedia_Sample_Apps.res` - Overall result (PASS/FAIL/SKIP)

### Logs
```
logs/Multimedia_Sample_Apps/
├── <app-name>.log       # Individual app logs
└── gst.log              # GStreamer debug output
```

---

## Validation

Each sample app is validated for:
- **Exit Code**: 0 (clean exit) or 124 (timeout) are considered success
- **GStreamer Errors**: No critical GStreamer errors in logs
- **Execution**: App runs for the specified timeout duration

---

## Troubleshooting

### App Not Found
```bash
# Check if apps are installed
ls -l /usr/bin/gst-*

# Verify specific app
ls -l /usr/bin/<app-name>
```

### App Not Executable
```bash
# Make app executable
chmod +x /usr/bin/<app-name>
```

### App Fails to Run
- Check logs in `logs/Multimedia_Sample_Apps/<app-name>.log`
- Review GStreamer debug log: `logs/Multimedia_Sample_Apps/gst.log`
- Verify required GStreamer plugins are installed
- Check for missing dependencies

### Python Apps
- Python apps (.py) must be executable with proper shebang
- Ensure Python 3 is installed: `python3 --version`
- Check Python GStreamer bindings:
  ```bash
  python3 -c "import gi; gi.require_version('Gst', '1.0')"
  ```

### Camera Apps
- Verify camera hardware is connected
- Check camera devices: `ls -l /dev/video*`
- Ensure camera permissions: `sudo usermod -a -G video $USER`
- For Config2 apps, verify qtiqmmfsrc: `gst-inspect-1.0 qtiqmmfsrc`

### Display Apps
- Verify Weston is running: `echo $WAYLAND_DISPLAY`
- Check display connection: `cat /sys/class/drm/card*/status`
- Verify waylandsink plugin: `gst-inspect-1.0 waylandsink`

---

## Configuration

The `Multimedia_Sample_Apps.yaml` file defines:
- All sample apps organized by category (audio, video, display, camera)
- Default timeouts and validation rules
- Build configuration dependencies
- App descriptions

---

## Directory Structure

```
Multimedia_Sample_Apps/
├── run.sh                          # Main test script
├── Multimedia_Sample_Apps.yaml     # Configuration for all apps
└── README.md                       # This file
```

---

## Notes

- Apps are executed from `/usr/bin/` with no additional parameters
- Each app runs for 30 seconds (default) and is terminated with SIGINT (Ctrl+C)
- Apps that run continuously until timeout are considered successful
- LAVA-compatible (always exits 0, writes .res file)
- Uses `lib_gstreamer.sh` for common GStreamer functions
- Follows the same pattern as other GStreamer test suites

---

## Integration

This test suite integrates with the Qualcomm Linux Testkit framework:
- Sources `init_env`, `functestlib.sh`, and `lib_gstreamer.sh`
- LAVA-friendly (exits 0, writes .res)
- Supports individual app and category execution
- Provides detailed logging and error reporting
- Compatible with CI/CD pipelines

---

## See Also

- [Camera_Tests](../../Camera/Camera_Tests/) - Comprehensive camera test suite
- [Video_Encode_Decode](../../Video/Video_Encode_Decode/) - Video encode/decode tests
- [lib_gstreamer.sh](../../../../utils/lib_gstreamer.sh) - GStreamer utility functions