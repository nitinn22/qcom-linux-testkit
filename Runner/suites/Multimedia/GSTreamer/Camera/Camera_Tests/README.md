# Camera Tests - GStreamer Camera Validation

## Overview

Validates camera functionality using GStreamer with two camera source plugins:
- **qtiqmmfsrc** (Qualcomm CAMX downstream) - 22 tests (12 standard + 10 interactive feature tests)
- **libcamerasrc** (upstream) - 9 tests

Auto-detects available plugin (prioritizes qtiqmmfsrc). Use `--plugin` to explicitly select.

## Prerequisites

### Required Tools
- `gst-launch-1.0` - GStreamer command-line tool
- `gst-inspect-1.0` - GStreamer plugin inspector

### Required Plugins

**qtiqmmfsrc:**
- `qtiqmmfsrc` - Qualcomm camera source
- `v4l2h264enc` - H.264 encoder (for encode tests)
- `waylandsink` - Display sink (for preview tests)
- `expect` - Interactive automation tool (for feature tests only)

**libcamerasrc:**
- `libcamerasrc` - Upstream camera source
- `videoconvert` - Format converter (required)
- `v4l2h264enc` - H.264 encoder (for encode tests)
- `waylandsink` - Display sink (for preview tests)

### Hardware
- Camera hardware
- Weston display server (for preview tests)
- Write permissions to output directories

## Test Matrix

### qtiqmmfsrc Tests (22 Total)

#### Standard Tests (12)

| Category | Tests | Formats | Resolutions | Description |
|----------|-------|---------|-------------|-------------|
| Fakesink | 2 | NV12, UBWC | 720p | Basic capture validation |
| Preview | 2 | NV12, UBWC | 4K | Display on Weston |
| Encode | 6 | NV12, UBWC | 720p, 1080p, 4K | H.264 encoding to MP4 |
| Snapshot | 2 | NV12 | 1080p, 4K | JPEG still image capture |

#### Interactive Feature Tests (10)

| Test | Feature | Description | Log Validation |
|------|---------|-------------|----------------|
| TC_001 | White Balance | Twilight mode (value: 10) | Mode:7 |
| TC_002 | Exposure Compensation | EC value: 10 | AECompensation:10 |
| TC_003 | Saturation | Saturation value: 0 | saturation 0 |
| TC_004 | Contrast | Contrast value: 10 | Manual Contrast Level = 9 |
| TC_005 | Manual Exposure | Exposure time: 33333μs | Exposure Time: 33333 |
| TC_006 | Anti-banding | 60Hz mode (value: 2) | InputAntiBandingMode:2 |
| TC_007 | Sharpness | Sharpness value: 3 | sharpness 1.5 |
| TC_008 | ISO Mode | ISO 800 | (No validation) |
| TC_009 | ADRC | ADRC enabled (value: 1) | ADRC: 1 |
| TC_010 | FRC | Frame Rate Control | PCR FRC enable |

**Feature Test Notes:**
- Uses `gst-pipeline-app` with automated interactive inputs
- 3-second delay between inputs (fixed)
- Captures journalctl logs for validation
- Applies CAMX override settings for detailed logging
- All tests run at 720p@30fps resolution

**Format Notes:**
- **NV12**: Standard linear format (universal support)
- **UBWC**: Qualcomm compressed format (Qualcomm optimized)
- **Snapshot**: Uses NV12 format only
- **Feature Tests**: Use NV12_Q08C (UBWC) format

### libcamerasrc Tests (9 Total)

| Category | Tests | Resolutions | Description |
|----------|-------|-------------|-------------|
| Fakesink | 2 | 720p, 1080p | Basic capture validation |
| Preview | 2 | 720p, 1080p | Display on Weston |
| Encode | 3 | 720p, 1080p, 4K | H.264 encoding to MP4 |
| Snapshot | 2 | 1080p, 4K | Still image capture (JPEG) |

**Format Notes:**
- Only supports NV12 format
- Requires `videoconvert` element
- Snapshot tests use `src_1::stream-role=still-capture` for high-quality stills

## Parameters

### Command Line Options

```bash
./run.sh [OPTIONS]

--camera-id <id>        Camera device ID (qtiqmmfsrc only, default: 0)
--plugin <name>         Plugin: qtiqmmfsrc, libcamerasrc, auto (default: auto)
--test-modes <list>     Modes: fakesink,preview,encode,snapshot,features (default: all except features)
--formats <list>        Formats: nv12,ubwc (qtiqmmfsrc only, default: both)
--resolutions <list>    Resolutions: 720p,1080p,4k (default: all)
--framerate <fps>       Framerate (default: 30)
--duration <seconds>    Test duration (default: 10)
--gst-debug <level>     Debug level 1-9 (default: 2)
-h, --help              Display help
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CAMERA_ID` | Camera device ID (qtiqmmfsrc only) | 0 |
| `CAMERA_PLUGIN` | Plugin: qtiqmmfsrc, libcamerasrc, auto | auto |
| `CAMERA_TEST_MODES` | Test modes (comma-separated) | fakesink,preview,encode,snapshot |
| `CAMERA_FORMATS` | Formats (qtiqmmfsrc only) | nv12,ubwc |
| `CAMERA_RESOLUTIONS` | Resolutions | 720p,1080p,4k |
| `CAMERA_FRAMERATE` | Framerate (fps) | 30 |
| `CAMERA_DURATION` | Duration (seconds) | 10 |
| `CAMERA_GST_DEBUG` | Debug level (1-9) | 2 |

### Usage Examples

```bash
# Run all tests (auto-detect)
./run.sh

# Test specific plugin
./run.sh --plugin qtiqmmfsrc
./run.sh --plugin libcamerasrc

# Run specific test modes
./run.sh --plugin qtiqmmfsrc --test-modes fakesink
./run.sh --plugin libcamerasrc --test-modes preview,encode

# Run qtiqmmfsrc interactive feature tests (10 tests)
./run.sh --plugin qtiqmmfsrc --test-modes features

# Run libcamerasrc snapshot tests (2 tests: 1080p and 4K)
./run.sh --plugin libcamerasrc --test-modes snapshot

# Run all qtiqmmfsrc tests including features (22 tests total)
./run.sh --plugin qtiqmmfsrc --test-modes fakesink,preview,encode,snapshot,features

# Test specific formats/resolutions
./run.sh --plugin qtiqmmfsrc --formats nv12 --resolutions 720p,1080p
./run.sh --plugin libcamerasrc --resolutions 4k --duration 20

# Using environment variables
export CAMERA_PLUGIN="qtiqmmfsrc"
export CAMERA_FORMATS="ubwc"
./run.sh
```

## Output

### Result Files
- `Camera_Tests.res` - Overall result (PASS/FAIL/SKIP)

### Logs
```
logs/Camera_Tests/
├── <testname>.log       # Individual test logs
├── gst.log              # GStreamer debug output
├── dmesg/               # Kernel logs
└── encoded/             # Encoded MP4 files
    └── *.mp4
```

## Troubleshooting

### Test Skipped

**Plugin not available:**
```bash
gst-inspect-1.0 qtiqmmfsrc
gst-inspect-1.0 libcamerasrc
gst-inspect-1.0 v4l2h264enc
gst-inspect-1.0 waylandsink
gst-inspect-1.0 videoconvert  # libcamerasrc only
```

**Camera not detected:**
```bash
ls -l /dev/video*
dmesg | grep camera
```

**Weston not running:**
```bash
echo $WAYLAND_DISPLAY
# Start Weston if needed
```

### Test Failed

**Permission denied:**
```bash
# Add user to video group
sudo usermod -a -G video $USER
# Logout and login required
```

**No output file / File too small:**
- Check camera connection and power
- Verify camera permissions: `ls -l /dev/video*`
- Check output directory write permissions
- Review logs in `logs/Camera_Tests/`

**Format not supported:**
- qtiqmmfsrc: Check capabilities with `v4l2-ctl --list-formats-ext`
- libcamerasrc: Only supports NV12
- UBWC is qtiqmmfsrc-specific (Qualcomm compressed format)

**Preview not displaying:**
- Verify Weston is running: `echo $WAYLAND_DISPLAY`
- Check XDG_RUNTIME_DIR is set
- Ensure display permissions are correct

### Common Issues

1. **Camera not detected**
   - Verify hardware connection
   - Check kernel logs: `dmesg | grep camera`
   - List devices: `ls -l /dev/video*`

2. **GStreamer errors**
   - Check `logs/Camera_Tests/gst.log`
   - Check `logs/Camera_Tests/<testname>.log`
   - Check `logs/Camera_Tests/dmesg/`

3. **Weston required for preview**
   - Preview tests require Weston compositor
   - Tests will be skipped if Weston not available

## Interactive Feature Tests (qtiqmmfsrc only)

The "features" test mode runs 10 automated interactive tests that validate camera property controls:

### Prerequisites
- `expect` tool for interactive automation (install with package manager if not present)
- CAMX logging enabled (automatically configured)

### Test Details
- **Resolution**: 720p@30fps (fixed)
- **Format**: NV12_Q08C (UBWC)
- **Input Delay**: 3 seconds between commands (fixed)
- **Validation**: Journalctl log markers

### Running Feature Tests
```bash
# Run all 10 feature tests
./run.sh --plugin qtiqmmfsrc --test-modes features

# Run features with other tests
./run.sh --plugin qtiqmmfsrc --test-modes fakesink,features

# Run complete qtiqmmfsrc test suite (22 tests)
./run.sh --plugin qtiqmmfsrc --test-modes fakesink,preview,encode,snapshot,features
```

### Feature Test Workflow
1. Apply CAMX override settings for detailed logging
2. Start journalctl log capture in background
3. Launch gst-pipeline-app with interactive inputs
4. Automated input sequence (3s delay between inputs):
   - Set pipeline to PLAYING
   - Access plugin properties
   - Configure feature value
   - Capture snapshots
   - Exit pipeline
5. Stop log capture
6. Validate expected markers in logs

### Troubleshooting Feature Tests
- **expect not found**: Install expect tool using your package manager
- **Log markers not found**: Check journalctl is capturing logs
- **Pipeline timeout**: Increase timeout if device is slow
- **CAMX settings not applied**: Verify write permissions to `/var/cache/camera/`

## Notes

- Auto-detection prioritizes qtiqmmfsrc when both available
- qtiqmmfsrc supports NV12 and UBWC formats
- libcamerasrc supports NV12 only
- UBWC is Qualcomm's compressed format (qtiqmmfsrc-specific)
- libcamerasrc requires `videoconvert` element
- All tests clean up GStreamer processes on exit
- LAVA-compatible (always exits 0)
- Feature tests use fixed 3-second delay between inputs
- Feature tests require `expect` tool for interactive automation

