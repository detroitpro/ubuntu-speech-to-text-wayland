#!/bin/bash
set -e

INSTALL_DIR="$HOME/.whisper-autopaste"
VENV_PATH="$INSTALL_DIR/venv"
SERVICE_NAME="whisper-autopaste.service"
SCRIPT_PATH="$INSTALL_DIR/whisper_auto_paste.py"
LOG_FILE="$INSTALL_DIR/whisper_auto_paste.log"

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
import logging
import time

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

samplerate = 16000
model_name = os.getenv("WHISPER_MODEL", "base")
logging.info(f"Loading Whisper model: {model_name}")
model = whisper.load_model(model_name)
recording = []
is_recording = False
recording_lock = threading.Lock()

def start_recording():
    global recording, is_recording
    with recording_lock:
        if is_recording:
            logging.warning('Recording already in progress, ignoring start request.')
            return
        is_recording = True
        recording = []
        logging.debug('Recording started')

    def callback(indata, frames, time, status):
        with recording_lock:
            if is_recording:
                recording.append(indata.copy())
                logging.debug(f'Recorded {frames} frames')

    with sd.InputStream(samplerate=samplerate, channels=1, dtype='int16', callback=callback):
        while True:
            with recording_lock:
                if not is_recording:
                    break
            sd.sleep(100)

def stop_and_transcribe():
    global recording, is_recording
    with recording_lock:
        if not is_recording:
            logging.warning('No recording in progress, ignoring stop request.')
            return
        is_recording = False
        logging.debug('Recording stopped')
        local_recording = recording.copy()
        recording = []  # Clear buffer immediately

    if not local_recording:
        logging.debug('No audio data recorded')
        return

    audio_data = np.concatenate(local_recording, axis=0)
    logging.debug(f'Audio data length: {len(audio_data)}')

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        write(f.name, samplerate, audio_data)
        audio_path = f.name
        logging.debug(f'Audio file created at {audio_path}')

    result = model.transcribe(audio_path)
    text = result["text"].strip()
    logging.debug(f'Transcription result: {text}')
    # os.remove(audio_path) # Commented out to inspect the audio file
    logging.info(f"Retained audio file at: {audio_path}")

    print("Transcribed:", text)
    if text:
        # Clear clipboard first, then set new text
        subprocess.run("wl-copy --clear", shell=True)
        time.sleep(0.1)  # Small delay to ensure clipboard is cleared
        subprocess.run(f"echo '{text}' | wl-copy", shell=True)
        time.sleep(0.2)  # Delay to ensure clipboard is set before pasting
        logging.debug(f'Text copied to clipboard: {text}')
        subprocess.run(["ydotool", "key", "29:1", "47:1", "47:0", "29:0"])  # Ctrl+V
        logging.debug('Paste command sent')
    else:
        logging.info("No text transcribed, skipping copy-paste.")

def on_press(key):
    if key == keyboard.Key.ctrl_r:
        with recording_lock:
            if not is_recording:
                logging.debug('Right Ctrl key pressed, starting recording')
                print("Recording...")
                threading.Thread(target=start_recording, daemon=True).start()

def on_release(key):
    if key == keyboard.Key.ctrl_r:
        with recording_lock:
            if is_recording:
                logging.debug('Right Ctrl key released, stopping recording and starting transcription')
                print("Transcribing...")
        # Run transcription in separate thread to avoid blocking the key listener
        threading.Thread(target=stop_and_transcribe, daemon=True).start()

with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()
EOF

chmod +x "$SCRIPT_PATH"

echo "==> Ensuring log directory and file exist with correct permissions..."
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 664 "$LOG_FILE"

echo "==> Creating systemd user service for whisper..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/$SERVICE_NAME" <<EOF
[Unit]
Description=Whisper Auto Paste Speech-to-Text
After=graphical.target

[Service]
ExecStart=$VENV_PATH/bin/python $SCRIPT_PATH
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
Restart=always
Environment=PATH=/usr/bin:/usr/local/bin:/sbin:/usr/sbin
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment=WHISPER_MODEL=small

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
