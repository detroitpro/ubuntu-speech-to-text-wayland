#!/bin/bash
set -e

echo "==> Installing system-wide dependencies..."
sudo apt update
sudo apt install -y ffmpeg wl-clipboard python3-venv python3-pyaudio python3-tk libevdev-dev libudev-dev libinput-dev cmake g++ git scdoc

echo "==> Cloning and building ydotool..."
rm -rf ~/ydotool
git clone https://github.com/ReimuNotMoe/ydotool.git ~/ydotool
mkdir ~/ydotool/build
cd ~/ydotool/build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_DOCUMENTATION=OFF
make
sudo make install

echo "==> Setting up uinput permissions for ydotool..."
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/99-uinput.rules
sudo usermod -aG input "$USER"
sudo udevadm control --reload-rules

echo "✅ Root-level setup complete. Please log out and log back in before running user.sh."
