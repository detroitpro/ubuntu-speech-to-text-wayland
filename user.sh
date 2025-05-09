#!/bin/bash
set -e

INSTALL_DIR="$HOME/.whisper-autopaste"
VENV_PATH="$INSTALL_DIR/venv"
SERVICE_NAME="whisper-autopaste.service"
SCRIPT_PATH="$INSTALL_DIR/whisper_auto_paste.py"

echo "==> Creating Python virtual environment..."
mkdir -p "$INSTALL_DIR"
python3 -m venv "$VENV_PATH"

echo "==> Installing Python packages in venv..."
"$VENV_PATH/bin/pip" install --upgrade pip
"$VENV_PATH/bin/pip" install openai-whisper sounddevice numpy pynput scipy

echo "==> Writing transcription script..."
cat > "$SCRIPT_PATH" << 'EOF'
import sounddevice as sd
import numpy as np
import whisper
import tempfile
import os
import subprocess
from pynput import keyboard
from scipy.io.wavfile import write
import threading

samplerate = 16000
model = whisper.load_model("base")
recording = []
is_recording = False

def start_recording():
    global recording, is_recording
    is_recording = True
    recording = []

    def callback(indata, frames, time, status):
        if is_recording:
            recording.append(indata.copy())

    with sd.InputStream(samplerate=samplerate, channels=1, dtype='int16', callback=callback):
        while is_recording:
            sd.sleep(100)

def stop_and_transcribe():
    global recording, is_recording
    is_recording = False
    if not recording:
        return

    audio_data = np.concatenate(recording, axis=0)

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        write(f.name, samplerate, audio_data)
        audio_path = f.name

    result = model.transcribe(audio_path)
    text = result["text"].strip()
    os.remove(audio_path)

    print("Transcribed:", text)
    subprocess.run(f"echo '{text}' | wl-copy", shell=True)
    subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"])  # Ctrl+V

def on_press(key):
    if key == keyboard.Key.ctrl_r and not is_recording:
        print("Recording...")
        threading.Thread(target=start_recording, daemon=True).start()

def on_release(key):
    if key == keyboard.Key.ctrl_r and is_recording:
        print("Transcribing...")
        stop_and_transcribe()

with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()
EOF

chmod +x "$SCRIPT_PATH"

echo "==> Creating systemd user service for whisper..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/$SERVICE_NAME" <<EOF
[Unit]
Description=Whisper Auto Paste Speech-to-Text
After=graphical.target

[Service]
ExecStart=$VENV_PATH/bin/python $SCRIPT_PATH
Restart=always
Environment=PATH=/usr/bin:/usr/local/bin
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/%U

[Install]
WantedBy=default.target
EOF

echo "==> Creating systemd user service for ydotoold..."
cat > "$HOME/.config/systemd/user/ydotoold.service" <<EOF
[Unit]
Description=Ydotool Daemon
After=graphical.target

[Service]
ExecStart=/usr/bin/ydotoold
Restart=always

[Install]
WantedBy=default.target
EOF

echo "==> Enabling whisper-autopaste and ydotoold services..."
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable ydotoold.service
systemctl --user enable whisper-autopaste.service
systemctl --user start ydotoold.service
systemctl --user start whisper-autopaste.service

echo "✅ User-level setup complete. Transcription and auto-paste are now active!"
