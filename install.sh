#!/bin/bash

set -e

USERNAME="detroitpro"
HOME_DIR="/home/$USERNAME"
INSTALL_DIR="$HOME_DIR/.whisper-autopaste"
VENV_PATH="$INSTALL_DIR/venv"
SERVICE_NAME="whisper-autopaste.service"
SCRIPT_PATH="$INSTALL_DIR/whisper_auto_paste.py"

echo "==> Installing system dependencies..."
sudo apt update
sudo apt install -y ffmpeg wl-clipboard python3-venv python3-pyaudio python3-tk libevdev-dev libudev-dev libinput-dev cmake g++ git

echo "==> Creating virtual environment..."
python3 -m venv "$VENV_PATH"

echo "==> Activating venv and installing Python packages..."
"$VENV_PATH/bin/pip" install --upgrade pip
"$VENV_PATH/bin/pip" install openai-whisper sounddevice numpy pynput

echo "==> Creating script directory..."
mkdir -p "$INSTALL_DIR"

echo "==> Writing whisper_auto_paste.py..."
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

echo "==> Cloning and building ydotool..."
cd "$HOME_DIR"
rm -rf "$HOME_DIR/ydotool"
git clone https://github.com/ReimuNotMoe/ydotool.git "$HOME_DIR/ydotool"
cd "$HOME_DIR/ydotool"
cmake . -DBUILD_DOCS=OFF
make
sudo make install

echo "==> Setting up uinput permissions for ydotool..."
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/99-uinput.rules
sudo usermod -aG input "$USERNAME"
sudo udevadm control --reload-rules

echo "==> Creating systemd user service..."
mkdir -p "$HOME_DIR/.config/systemd/user"
cat > "$HOME_DIR/.config/systemd/user/$SERVICE_NAME" <<EOF
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

echo "==> Enabling linger and user service..."
sudo loginctl enable-linger "$USERNAME"
sudo chown -R "$USERNAME:$USERNAME" "$INSTALL_DIR" "$HOME_DIR/.config/systemd/user/$SERVICE_NAME"
sudo chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.config/systemd"

sudo -u "$USERNAME" systemctl --user daemon-reexec
sudo -u "$USERNAME" systemctl --user daemon-reload
sudo -u "$USERNAME" systemctl --user enable "$SERVICE_NAME"
sudo -u "$USERNAME" systemctl --user start "$SERVICE_NAME"

echo "✅ Setup complete!"
echo "Please logout and log back in (or reboot) to apply group permissions for ydotool."
