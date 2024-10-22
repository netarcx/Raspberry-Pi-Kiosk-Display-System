#!/bin/bash

# To set up, you will need an up-to-date Raspberry Pi OS Bookworm. 
# We have tested this with "2024-07-04-raspios-bookworm-arm64-lite" on a Raspberry Pi 5. Should also work out of the box on a Raspberry Pi 4.
# For ease of use, take Raspberry Pi Imager. Set Wi-Fi, SSH, and hostname as per your needs.
# Then flash your SD card.

# Copy this script to your running Raspberry Pi system and call the script not as a root user:
# bash kiosk_setup.sh

# History
# 2024-10-22 v1.0: Initial release

# Function to display a spinner with additional message
spinner() {
    local pid=$1  # Receive the PID of the background process
    local message=$2  # Receive the message to display with the spinner
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")  # spinner frames
    tput civis  # Hide cursor
    local i=0
    while [ -d /proc/$pid ]; do  # Check if the process is still running
        local frame=${frames[$i]}
        printf "\r\e[35m%s\e[0m %s" "$frame" "$message"  # Print spinner frame with the message
        i=$(((i + 1) % ${#frames[@]}))
        sleep $delay
    done
    printf "\r\e[32m✔\e[0m %s\n" "$message"  # Show green checkmark when done
    tput cnorm  # Restore cursor
}

# Check if the script is being run as root, exit if true
if [ "$(id -u)" -eq 0 ]; then
  echo "This script should not be run as root. Please run as a regular user with sudo permissions."
  exit 1
fi

# Get the current username
CURRENT_USER=$(whoami)

# Function to prompt the user for y/n input
ask_user() {
    local prompt="$1"
    while true; do
        read -p "$prompt (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;  # Continue if yes
            [Nn]* ) return 1;;  # Skip if no
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# update the package list?
echo
if ask_user "Do you want to update the package list?"; then
    echo -e "\e[90mUpdating the package list, please wait...\e[0m"
    sudo apt update > /dev/null 2>&1 &
    spinner $! "Updating package list..."
fi

# upgrade installed packages?
echo
if ask_user "Do you want to upgrade installed packages?"; then
    echo -e "\e[90mUpgrading installed packages. THIS MAY TAKE SOME TIME, please wait...\e[0m"
    sudo apt upgrade -y > /dev/null 2>&1 &
    spinner $! "Upgrading installed packages..."
fi

# install Chromium Browser?
echo
if ask_user "Do you want to install Chromium Browser?"; then
    echo -e "\e[90mInstalling Chromium Browser, please wait...\e[0m"
    sudo apt install --no-install-recommends -y chromium-browser > /dev/null 2>&1 &
    spinner $! "Installing Chromium Browser..."
fi

# install Wayland packages and Wayfire config?
echo
if ask_user "Do you want to install Wayland packages and do Wayfire default config?"; then
    echo -e "\e[90mInstalling Wayland packages, please wait...\e[0m"
    sudo apt install --no-install-recommends -y wayfire seatd xdg-user-dirs mesa-utils libgl1-mesa-dri > /dev/null 2>&1 &
    spinner $! "Installing Wayland packages..."
    
    # Create the wayfire.ini configuration file if it doesn't exist
    echo -e "\e[90mSetting up Wayfire configuration...\e[0m"
    mkdir -p ~/.config
    
    if [ ! -f ~/.config/wayfire.ini ]; then
        cat <<EOL > ~/.config/wayfire.ini
[core]
plugins = \\
  autostart \\
  hide-cursor
  
[autostart]
chromium = chromium-browser --incognito --autoplay-policy=no-user-gesture-required --kiosk https://webglsamples.org/aquarium/aquarium.html
EOL
        echo -e "\e[32mwayfire.ini file created and configured.\e[0m"
    else
        echo -e "\e[33mwayfire.ini already exists, skipping creation.\e[0m"
    fi
fi

# Combine resolution configuration for both cmdline.txt and wayfire.ini into one block
echo
if ask_user "Do you want to configure a resolution in cmdline.txt and wayfire.ini?"; then
    # List of common resolutions
    resolutions=("1920x1080@60" "1280x720@60" "1024x768@60" "1600x900@60" "1366x768@60")

    # Prompt user to choose a resolution
    echo -e "\e[94mPlease choose a resolution:\e[0m"
    select RESOLUTION in "${resolutions[@]}"; do
        if [[ -n "$RESOLUTION" ]]; then
            echo -e "\e[32mYou selected $RESOLUTION\e[0m"
            break
        else
            echo -e "\e[33mInvalid selection, please try again.\e[0m"
        fi
    done

    # Add resolution to /boot/firmware/cmdline.txt if not already present
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
    if ! grep -q "video=" "$CMDLINE_FILE"; then
        echo -e "\e[90mAdding video=$RESOLUTION to $CMDLINE_FILE...\e[0m"
        sudo sed -i "1s/^/video=HDMI-A-1:$RESOLUTION /" "$CMDLINE_FILE"
        echo -e "\e[32mResolution added to cmdline.txt successfully!\e[0m"
    else
        echo -e "\e[33mcmdline.txt already contains a video entry. No changes made.\e[0m"
    fi

    # Add resolution to wayfire.ini
    WAYFIRE_CONFIG_DIR="$HOME/.config"
    WAYFIRE_CONFIG_FILE="$WAYFIRE_CONFIG_DIR/wayfire.ini"
    echo -e "\e[90mAdding resolution to wayfire.ini...\e[0m"
    if ! grep -q "\[output:HDMI-A-1\]" "$WAYFIRE_CONFIG_FILE"; then
        mkdir -p "$WAYFIRE_CONFIG_DIR"
        echo -e "\n[output:HDMI-A-1]\nmode = $RESOLUTION" >> "$WAYFIRE_CONFIG_FILE"
        echo -e "\e[32mResolution added to wayfire.ini successfully!\e[0m"
    else
        echo -e "\e[33mwayfire.ini already contains an output entry for HDMI-A-1. No changes made.\e[0m"
    fi
fi

# install Wayfire hide cursor plugin?
echo
if ask_user "Do you want to install the Wayfire hide cursor plugin?"; then
    echo -e "\e[90mInstalling Wayfire hide cursor plugin, please wait...\e[0m"
    wget https://github.com/seffs/wayfire-plugins-extra-raspbian/releases/download/v0.7.5/wayfire-plugins-extra-raspbian-aarch64.tar.xz > /dev/null 2>&1 &
    spinner $! "Downloading Wayfire hide cursor plugin..."

    echo -e "\e[90mExtracting plugin files...\e[0m"
    tar xf wayfire-plugins-extra-raspbian-aarch64.tar.xz > /dev/null 2>&1 &
    spinner $! "Extracting plugin files..."

    echo -e "\e[90mCopying plugin files to the system...\e[0m"
    sudo cp usr/share/wayfire/metadata/hide-cursor.xml /usr/share/wayfire/metadata/
    sudo cp usr/lib/aarch64-linux-gnu/wayfire/libhide-cursor.so /usr/lib/aarch64-linux-gnu/wayfire/

    # Clean up downloaded and extracted files
    echo -e "\e[90mCleaning up temporary files...\e[0m"
    rm -rf ./usr
    rm wayfire-plugins-extra-raspbian-aarch64.tar.xz
fi

# install and configure greetd?
echo
if ask_user "Do you want to install and configure greetd for auto start of Wayfire?"; then
    # Install greetd
    echo -e "\e[90mInstalling greetd for auto start of Wayfire, please wait...\e[0m"
    sudo apt install -y greetd > /dev/null 2>&1 &
    spinner $! "Installing greetd..."

    # Create or overwrite /etc/greetd/config.toml
    echo -e "\e[90mCreating or overwriting config.toml...\e[0m"

    sudo mkdir -p /etc/greetd
    sudo bash -c "cat <<EOL > /etc/greetd/config.toml
[terminal]
vt = 7
[default_session]
command = \"/usr/bin/wayfire\"
user = \"$CURRENT_USER\"
EOL"

    echo -e "\e[32mconfig.toml has been created or overwritten successfully!\e[0m"

    # Enable greetd service and set graphical target
    echo -e "\e[90mEnabling greetd service...\e[0m"
    sudo systemctl enable greetd > /dev/null 2>&1 &
    spinner $! "Enabling greetd service..."

    echo -e "\e[90mSetting graphical target as the default...\e[0m"
    sudo systemctl set-default graphical.target > /dev/null 2>&1 &
    spinner $! "Setting graphical target..."
fi

# install Plymouth splash screen?
echo
if ask_user "Do you want to install the Plymouth splash screen?"; then
    # Update /boot/firmware/config.txt
    CONFIG_TXT="/boot/firmware/config.txt"
    if ! grep -q "disable_splash" "$CONFIG_TXT"; then
        echo -e "\e[90mAdding disable_splash=1 to $CONFIG_TXT...\e[0m"
        sudo bash -c "echo 'disable_splash=1' >> $CONFIG_TXT"
    else
        echo -e "\e[33m$config_txt already contains a disable_splash option. No changes made. Please check manually!\e[0m"
    fi

    # Update /boot/firmware/cmdline.txt
    CMDLINE_TXT="/boot/firmware/cmdline.txt"
    if ! grep -q "splash" "$CMDLINE_TXT"; then
        echo -e "\e[90mAdding quiet splash plymouth.ignore-serial-consoles to $CMDLINE_TXT...\e[0m"
        sudo sed -i 's/$/ quiet splash plymouth.ignore-serial-consoles/' "$CMDLINE_TXT"
    else
        echo -e "\e[33m$cmdline_txt already contains splash options. No changes made. Please check manually!\e[0m"
    fi

    # Install Plymouth and themes
    echo -e "\e[90mInstalling Plymouth and themes...\e[0m"
    sudo apt install -y plymouth plymouth-themes > /dev/null 2>&1 &
    spinner $! "Installing Plymouth..."

    # List available themes and store them in an array
    echo -e "\e[90mListing available Plymouth themes...\e[0m"
    readarray -t THEMES < <(plymouth-set-default-theme -l)  # Store themes in an array

    # Prompt user to choose a theme
    echo -e "\e[94mPlease choose a theme (enter the number):\e[0m"
    select SELECTED_THEME in "${THEMES[@]}"; do
        if [[ -n "$SELECTED_THEME" ]]; then
            echo -e "\e[90mSetting Plymouth theme to $SELECTED_THEME...\e[0m"
            sudo plymouth-set-default-theme $SELECTED_THEME
            sudo update-initramfs -u > /dev/null 2>&1 &
            spinner $! "Updating initramfs..."
            echo -e "\e[32mPlymouth splash screen installed and configured with $SELECTED_THEME theme.\e[0m"
            break
        else
            echo -e "\e[31mInvalid selection, please try again.\e[0m"
        fi
    done
fi

# cleaning up apt caches
echo -e "\e[90mCleaning up apt caches, please wait...\e[0m"
sudo apt clean > /dev/null 2>&1 &
spinner $! "Cleaning up apt caches..."

# Print completion message
echo -e "\e[32mSetup completed successfully! Please reboot your system.\e[0m"
