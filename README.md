# Whisper Auto Paste Setup

This project sets up a system where holding **Right Ctrl** records your speech,
then automatically transcribes it using Whisper and pastes it into the focused text field.

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

