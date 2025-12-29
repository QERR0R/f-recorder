#!/bin/bash

FILENAME="screen_recording_$(date +'%Y%m%d_%H%M%S')"
OUTPUT_FORMAT="mp4"
FULL_FILENAME="${FILENAME}.${OUTPUT_FORMAT}"

echo "🎥 FFmpeg Screen Recorder"
echo "========================="

read -p "Enter framerate [default: 30]: " FRAMERATE
FRAMERATE=${FRAMERATE:-30}

echo -n "Record audio? [y/N]: "
read RECORD_AUDIO
RECORD_AUDIO=${RECORD_AUDIO:-n}

echo "Select quality:"
echo "1) High (Large file)"
echo "2) Medium (Recommended)"
echo "3) Low (Small file)"
read -p "Enter choice [2]: " QUALITY_CHOICE
QUALITY_CHOICE=${QUALITY_CHOICE:-2}

case $QUALITY_CHOICE in
    1) CRF="18" ;;  # High quality
    2) CRF="23" ;;  # Medium quality
    3) CRF="28" ;;  # Low quality
    *) CRF="23" ;;  # Default medium
esac

echo -n "Custom resolution? (e.g., 1920x1080) [Enter for auto-detect]: "
read CUSTOM_RES
if [[ -z "$CUSTOM_RES" ]]; then
    echo "Auto-detecting screen resolution..."
    RES_OPTION=""
else
    RES_OPTION="-s ${CUSTOM_RES}"
fi

read -p "Output directory [default: ./recordings]: " OUTPUT_DIR
OUTPUT_DIR=${OUTPUT_DIR:-./recordings}
mkdir -p "$OUTPUT_DIR"

echo ""
echo "📋 Recording Settings:"
echo "  Filename: $FULL_FILENAME"
echo "  Output: ${OUTPUT_DIR}/${FULL_FILENAME}"
echo "  Framerate: ${FRAMERATE}fps"
echo "  Quality: CRF ${CRF}"
echo ""

case "$(uname -s)" in
    Linux*)
        echo "🖥️  Linux detected"
        
        if [[ $XDG_SESSION_TYPE == "wayland" ]]; then
            echo "⚠️  Wayland detected - using wf-recorder (install if needed)"
            echo "For better compatibility, consider using X11 session"
            
            if command -v wf-recorder &> /dev/null; then
                read -p "Press Enter to start recording (Ctrl+C to stop)..."
                wf-recorder -f "${OUTPUT_DIR}/${FULL_FILENAME}"
            else
                echo "❌ wf-recorder not found. Install with: sudo apt install wf-recorder"
                exit 1
            fi
        else
            echo "Available screens/dindows:"
            xrandr | grep " connected"
            
            read -p "Enter screen (e.g., :0.0) [default: :0.0]: " SCREEN
            SCREEN=${SCREEN:-":0.0"}
            
            FFMPEG_CMD="ffmpeg -f x11grab $RES_OPTION -r $FRAMERATE -i $SCREEN"
            
            if [[ $RECORD_AUDIO =~ ^[Yy]$ ]]; then
                echo "Audio devices available:"
                pactl list short sources
                read -p "Enter audio device [default: alsa_output.pci-0000_00_1f.3.analog-stereo.monitor]: " AUDIO_DEVICE
                AUDIO_DEVICE=${AUDIO_DEVICE:-"alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"}
                FFMPEG_CMD="$FFMPEG_CMD -f pulse -i $AUDIO_DEVICE"
            fi
        fi
        ;;
        
    Darwin*)
        echo "🍎 macOS detected"
        
        if [[ $RECORD_AUDIO =~ ^[Yy]$ ]]; then
            echo "Available audio devices:"
            ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A 10 "audio devices"
            read -p "Enter audio device number [default: 0]: " AUDIO_DEVICE
            AUDIO_DEVICE=${AUDIO_DEVICE:-0}
        fi
        
        echo ""
        read -p "Enter screen number [default: 1]: " SCREEN_NUM
        SCREEN_NUM=${SCREEN_NUM:-1}
        
        FFMPEG_CMD="ffmpeg -f avfoundation -r $FRAMERATE -i \"$SCREEN_NUM:"
        
        if [[ $RECORD_AUDIO =~ ^[Yy]$ ]]; then
            FFMPEG_CMD="${FFMPEG_CMD}${AUDIO_DEVICE}\""
        else
            FFMPEG_CMD="${FFMPEG_CMD}\""
        fi
        ;;
        
    MINGW*|MSYS*|CYGWIN*)
        echo "🪟 Windows detected"
        
        read -p "Enter screen number [default: desktop]: " SCREEN_NUM
        SCREEN_NUM=${SCREEN_NUM:-"desktop"}
        
        FFMPEG_CMD="ffmpeg -f gdigrab -r $FRAMERATE -i $SCREEN_NUM"
        
        if [[ $RECORD_AUDIO =~ ^[Yy]$ ]]; then
            FFMPEG_CMD="$FFMPEG_CMD -f dshow -i audio=\"Stereo Mix (Realtek Audio)\""
        fi
        ;;
        
    *)
        echo "❌ Unsupported operating system"
        exit 1
        ;;
esac

FFMPEG_CMD="$FFMPEG_CMD -c:v libx264 -crf $CRF -preset fast -pix_fmt yuv420p"
FFMPEG_CMD="$FFMPEG_CMD \"${OUTPUT_DIR}/${FULL_FILENAME}\""

echo ""
echo "🚀 Starting recording with command:"
echo "ffmpeg [parameters] -> ${OUTPUT_DIR}/${FULL_FILENAME}"
echo ""
echo "⏺️  Recording started... Press 'q' in the terminal to stop."

if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* && $XDG_SESSION_TYPE != "wayland" ]]; then
    eval $FFMPEG_CMD
elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
    cmd //c "ffmpeg $FFMPEG_CMD"
fi

echo "✅ Recording saved to: ${OUTPUT_DIR}/${FULL_FILENAME}"
