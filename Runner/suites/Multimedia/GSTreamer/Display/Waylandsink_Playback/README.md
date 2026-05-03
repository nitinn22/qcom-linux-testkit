# Waylandsink_Playback (GStreamer) — Runner Test

This directory contains the **Waylandsink_Playback** validation test for Qualcomm Linux Testkit runners.

It validates **Wayland display** using **GStreamer waylandsink** with:
- Weston/Wayland server connectivity checks
- DRM display connectivity validation
- Video playback using `waylandsink` element
- Uses `videotestsrc` to generate test patterns
- **Runs 4 tests by default** at different resolutions: 480p, 720p, 1080p, 2160p

The script is designed to be **CI/LAVA-friendly**:
- Writes **PASS/FAIL/SKIP** into `Waylandsink_Playback.res`
- Always **exits 0** (even on FAIL/SKIP)
- Comprehensive Weston/Wayland environment detection
- Automatic Weston startup if needed
- Individual test case IDs for each resolution

---

## What this test does

1. Sources framework utilities (`functestlib.sh`, `lib_gstreamer.sh`, `lib_display.sh`)
2. **Display connectivity check**: Verifies connected DRM display via sysfs
3. **Weston/Wayland server check**:
   - Discovers existing Wayland socket
   - Attempts to start Weston if no socket found
   - Validates Wayland connection
4. **waylandsink element check**: Verifies GStreamer waylandsink is available
5. **Multi-resolution playback tests**: Runs 4 tests by default (480p, 720p, 1080p, 2160p)
6. **Validation**: Checks playback duration and exit code for each test

---

## Test Cases

By default, the test runs **4 separate test cases**:

1. **Waylandsink_Playback_480p** - 640x480 resolution test
2. **Waylandsink_Playback_720p** - 1280x720 resolution test
3. **Waylandsink_Playback_1080p** - 1920x1080 resolution test
4. **Waylandsink_Playback_2160p** - 3840x2160 resolution test

Each test case reports its result individually, plus an overall **Waylandsink_Playback** result.

---

## PASS / FAIL / SKIP criteria

### PASS
- Playback completes successfully (exit code 0)
- Elapsed time ≥ (duration - 2) seconds
- No GStreamer errors detected in logs

### FAIL
- Playback exits with error code (not 0)
- Playback exits too quickly (< duration - 2 seconds)
- GStreamer errors detected in logs
- Playback timeout

### SKIP
- Missing GStreamer tools (`gst-launch-1.0`, `gst-inspect-1.0`)
- No connected DRM display found
- No Wayland socket found (and cannot start Weston)
- Wayland connection test fails
- `waylandsink` element not available

---

## Dependencies

### Required
- `gst-launch-1.0`
- `gst-inspect-1.0`
- `videotestsrc` GStreamer plugin
- `videoconvert` GStreamer plugin
- `waylandsink` GStreamer plugin

### Display/Wayland
- Weston compositor (running or startable)
- Connected DRM display
- Wayland socket (`/run/user/*/wayland-*` or `/dev/socket/weston/wayland-*`)

---

## Usage

```bash
./run.sh [options]
```

### Options

- `--resolution <list>` - Comma-separated list of resolutions (e.g., "480p,720p,1080p,2160p") or single resolution. Supported: 480p, 720p, 1080p, 2160p (default: 480p,720p,1080p,2160p)
- `--duration <seconds>` - Playback duration in seconds (default: 30)
- `--pattern <smpte|snow|ball|etc>` - videotestsrc pattern (default: smpte)
- `--framerate <fps>` - Video framerate (default: 30)
- `--gst-debug <level>` - GStreamer debug level 1-9 (default: 2)
- `--lava-testcase-id <id>` - LAVA testcase ID prefix for result reporting (default: Waylandsink_Playback)

---

## Examples

### Basic Usage

```bash
# Run default 4 tests (480p, 720p, 1080p, 2160p)
./run.sh

# Run specific resolutions only
./run.sh --resolution "480p,1080p"

# Run single resolution test
./run.sh --resolution "480p"
./run.sh --resolution "720p"
./run.sh --resolution "1080p"
./run.sh --resolution "2160p"
```

### Custom Parameters

```bash
# Run with custom duration
./run.sh --duration 20

# Run with different pattern
./run.sh --pattern ball

# Run with higher framerate
./run.sh --framerate 60

# Run with higher debug level
./run.sh --gst-debug 5

# Combination of parameters
./run.sh --resolution "480p,720p" --duration 15 --pattern snow
```

### LAVA Integration

```bash
# Run with custom LAVA testcase ID
./run.sh --lava-testcase-id "Display_Waylandsink"
```

---

## Using run-test.sh

You can also run the test using the framework's `run-test.sh` script:

```bash
cd qcom-linux-testkit/Runner

# Run all 4 tests
./run-test.sh Waylandsink_Playback

# Run with custom parameters
./run-test.sh Waylandsink_Playback --resolution "480p,1080p"
./run-test.sh Waylandsink_Playback --duration 20 --pattern ball
```

---

## Pipeline

For each resolution test, the following pipeline is executed:

```
videotestsrc is-live=true num-buffers=<N> pattern=<pattern>
  ! video/x-raw,width=<W>,height=<H>,framerate=<FPS>/1
  ! videoconvert
  ! waylandsink
```

Where:
- `<N>` = duration × framerate
- `<W>` = width for the resolution (e.g., 640 for 480p)
- `<H>` = height for the resolution (e.g., 480 for 480p)
- `<FPS>` = framerate (default: 30)
- `<pattern>` = test pattern (default: smpte)

---

## Logs

```
./Waylandsink_Playback.res                    # Overall result file
./logs/
  Waylandsink_Playback_480p/
    gst.log      # GStreamer debug output for 480p test
    run.log      # Pipeline execution log for 480p test
  Waylandsink_Playback_720p/
    gst.log      # GStreamer debug output for 720p test
    run.log      # Pipeline execution log for 720p test
  Waylandsink_Playback_1080p/
    gst.log      # GStreamer debug output for 1080p test
    run.log      # Pipeline execution log for 1080p test
  Waylandsink_Playback_2160p/
    gst.log      # GStreamer debug output for 2160p test
    run.log      # Pipeline execution log for 2160p test
```

### Result File Format

The `.res` file contains individual results for each test:

```
Waylandsink_Playback_480p PASS
Waylandsink_Playback_720p PASS
Waylandsink_Playback_1080p PASS
Waylandsink_Playback_2160p PASS
Waylandsink_Playback PASS
```

---

## LAVA Integration

### YAML Test Definition

The test includes a LAVA-compatible YAML definition file: `Waylandsink_Playback.yaml`

### Environment Variables

The test supports these environment variables (can be set in LAVA job definition):

- `VIDEO_DURATION` - Playback duration in seconds (default: 30)
- `RUNTIMESEC` - Alternative to VIDEO_DURATION
- `VIDEO_PATTERN` - videotestsrc pattern (default: smpte)
- `VIDEO_RESOLUTION` - Comma-separated list of resolutions (default: 480p,720p,1080p,2160p)
- `VIDEO_FRAMERATE` - Video framerate (default: 30)
- `VIDEO_GST_DEBUG` - GStreamer debug level (default: 2)
- `GST_DEBUG_LEVEL` - Alternative to VIDEO_GST_DEBUG
- `LAVA_TESTCASE_ID` - LAVA testcase ID prefix (default: Waylandsink_Playback)

**Priority order for duration**: `VIDEO_DURATION` > `RUNTIMESEC` > default (30)

### LAVA Job Example

```yaml
- test:
    definitions:
    - from: git
      name: Waylandsink_Playback
      path: Runner/suites/Multimedia/GSTreamer/Display/Waylandsink_Playback/Waylandsink_Playback.yaml
      repository: https://github.com/qualcomm-linux/qcom-linux-testkit/
      parameters:
        VIDEO_RESOLUTION: "480p,720p,1080p,2160p"
        VIDEO_DURATION: "30"
        VIDEO_PATTERN: "smpte"
      expected:
      - Waylandsink_Playback_480p
      - Waylandsink_Playback_720p
      - Waylandsink_Playback_1080p
      - Waylandsink_Playback_2160p
      - Waylandsink_Playback
```

### Running Individual Tests in LAVA

To run only specific resolution tests:

```yaml
parameters:
  VIDEO_RESOLUTION: "480p"  # Run only 480p test
```

Or multiple specific resolutions:

```yaml
parameters:
  VIDEO_RESOLUTION: "480p,1080p"  # Run only 480p and 1080p tests
```

---

## Troubleshooting

### "SKIP: No connected DRM display found"
- Check physical display connection
- Verify DRM drivers loaded: `ls -l /dev/dri/`

### "SKIP: No Wayland socket found"
- Check if Weston is running: `pgrep weston`
- Try starting Weston manually
- Check `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY` environment variables

### "SKIP: waylandsink element not available"
- Install GStreamer Wayland plugin
- Check: `gst-inspect-1.0 waylandsink`

### "FAIL: Playback failed"
- Check logs in `logs/Waylandsink_Playback_<resolution>/`
- Increase debug level: `./run.sh --gst-debug 5`
- Verify Weston is running properly
- Check for GStreamer errors in `gst.log`

### "FAIL: GStreamer errors detected"
- Review the `gst.log` file for specific error messages
- Common issues:
  - Missing GStreamer plugins
  - Wayland connection issues
  - Display configuration problems

---

## Resolution Mapping

| Resolution Name | Width × Height | Description |
|----------------|----------------|-------------|
| 480p | 640 × 480 | Standard Definition |
| 720p | 1280 × 720 | HD Ready |
| 1080p | 1920 × 1080 | Full HD |
| 2160p | 3840 × 2160 | 4K Ultra HD |

---

## Test Summary

- **Default behavior**: Runs 4 tests at different resolutions
- **Flexible**: Can run individual or subset of resolutions
- **LAVA-friendly**: Each test has unique test case ID
- **Comprehensive logging**: Separate logs for each resolution
- **CI-ready**: Always exits 0, writes results to .res file
