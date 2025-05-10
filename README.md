# Whisper Auto Paste Setup

This project sets up a system on **Ubuntu with Wayland** where holding **Right Ctrl** records your speech, then automatically transcribes it using OpenAI\'s Whisper model and pastes the text into the currently focused application.

---

## 🛠 Prerequisites

- Ubuntu (with Wayland)
- Python 3.10+
- A working microphone

---

## 🔧 Installation Steps

### 1. Run root-level setup (installs system dependencies and ydotool)

```bash
chmod +x root.sh
sudo ./root.sh
```

**⚠️ Reboot or log out and log back in** to apply group permission changes (for `ydotool` to work without sudo).

---

### 2. Run user-level setup (sets up Whisper transcription and systemd service)

```bash
chmod +x user.sh
./user.sh
```

---

## ✅ Usage

- Hold **Right Ctrl** key → speak
- Release **Right Ctrl** → text is transcribed and auto-pasted

You can check the service status with:

```bash
systemctl --user status whisper-autopaste.service
```

---

## 🚫 To Stop or Disable

```bash
systemctl --user stop whisper-autopaste.service
systemctl --user disable whisper-autopaste.service
```

---

## ⚙️ Technical Details

- **Wayland Specific**: This setup is primarily designed for and tested on **Wayland** desktop environments.
    - It uses `wl-copy` (from `wl-clipboard`) for copying text to the clipboard.
    - It uses `ydotool` for simulating keyboard input (Ctrl+V for pasting). `ydotoold` must be running as a background service.
- **Systemd User Services**:
    - `whisper-autopaste.service`: Manages the main Python transcription script.
    - `ydotoold.service`: Runs the `ydotool` daemon required for input simulation.
    - These are user-level services, managed via `systemctl --user ...`.
- **Python Virtual Environment**: All Python dependencies (like `openai-whisper`, `sounddevice`, `pynput`) are installed in a dedicated virtual environment located at `~/.whisper-autopaste/venv/`.
- **Logging**:
    - The main transcription script logs its activity to `~/.whisper-autopaste/whisper_auto_paste.log`.
    - This includes recording start/stop, audio file paths, and transcription results.
- **Temporary Audio Files**:
    - Recorded audio is temporarily saved as a `.wav` file in the system\'s `/tmp/` directory.
    - Currently, these audio files are **not automatically deleted** after transcription to aid in debugging. You may want to periodically clear them manually from `/tmp/`.
- **Whisper Model**:
    - The script uses the `openai-whisper` library for transcription.
    - By default, it loads the `"base"` model. You can change this by setting the `WHISPER_MODEL` environment variable in the `whisper-autopaste.service` unit file.
    - For example, to use the `"small"` model, you can run `systemctl --user edit whisper-autopaste.service` and add/modify the `[Service]` section:
      ```ini
      [Service]
      Environment="WHISPER_MODEL=small"
      ```
    - Remember to run `systemctl --user daemon-reload` and `systemctl --user restart whisper-autopaste.service` after making changes. Larger models provide better accuracy but require more computational resources and are slower.
- **Key Binding**: The script listens for the **Right Ctrl** key to trigger recording. This is hardcoded in the Python script.

---

## 🐛 Troubleshooting & Known Issues

- **Audio Quality**: If transcriptions are poor, ensure your microphone input level is adequate in your system sound settings. The quality of the input audio significantly impacts transcription accuracy.
- **FP16 Warning**: You might see a warning in the logs: `"FP16 is not supported on CPU; using FP32 instead"`. This is expected when running Whisper on a CPU and does not prevent transcription.
- **Permissions**: The `root.sh` script sets up necessary permissions for `ydotool` by adding the user to the `input` group and creating a `udev` rule. A logout/login or reboot is required for these to take effect.

