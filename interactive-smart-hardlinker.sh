#!/bin/bash

#################################################################################################################################################
# Interactive-Smart-Hardlinker
#
# By default this script expects the directory structure
# /mnt/user/data/torrents and /mnt/user/data/media for the source and destination. 
# This directory structure follows the recommendations found in Trash Guides for Unraid.
# https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Unraid/
#
# Feel free to change the 'Base paths' as needed if you do not use this structure.
#
# Features interactive menus for source/destination selection, automatic inode checking to prevent duplicate 
# hardlinks, and optional verbose logging.
#
# Requirements: Must be run in an interactive shell (SSH recommended if being run on remote host)
#
# Created by: FoxyTheFoxer
# With assistance from: Claude AI (Anthropic)
#################################################################################################################################################

# Enable dotglob to include hidden files/directories in glob patterns
shopt -s dotglob

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base paths (Change as needed)
BASE_SOURCE="/mnt/user/data/torrents"
BASE_DEST="/mnt/user/data/media"

# Statistics
TOTAL_FILES=0
LINKED_FILES=0
SKIPPED_FILES=0
ERROR_FILES=0

# Log buffer for verbose output
LOG=""

# Function to print colored messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    LOG+="[ERROR] $1\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    LOG+="[SUCCESS] $1\n"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    LOG+="[WARNING] $1\n"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    LOG+="[INFO] $1\n"
}

# Function to log without printing to screen (for verbose log only)
log_verbose() {
    LOG+="[INFO] $1\n"
}

# Function to check if file is already hardlinked (link count > 1)
is_already_hardlinked() {
    local file="$1"
    local link_count=$(stat -c %h "$file" 2>/dev/null)
    
    if [ "$link_count" -gt 1 ]; then
        return 0  # Already hardlinked
    else
        return 1  # Not hardlinked
    fi
}

# Function to get user input with timeout
get_input_with_timeout() {
    local prompt="$1"
    local timeout_seconds="$2"
    local result
    
    if read -t "$timeout_seconds" -p "$prompt" result; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

# Function to navigate source directories hierarchically
navigate_source_directory() {
    local current_path="$BASE_SOURCE"
    local relative_path=""
    
    while true; do
        clear
        echo ""
        echo "==================================================="
        if [ -z "$relative_path" ]; then
            echo "Select Source Directory: $BASE_SOURCE"
        else
            echo "Current Path: $BASE_SOURCE/$relative_path"
        fi
        echo "==================================================="
        
        # Get immediate subdirectories only
        local index=1
        declare -a SUBDIRS
        
        if [ -d "$current_path" ]; then
            while IFS= read -r dir; do
                SUBDIRS[$index]=$(basename "$dir")
                echo "  [$index] ${SUBDIRS[$index]}"
                ((index++))
            done < <(find "$current_path" -mindepth 1 -maxdepth 1 -type d | sort)
        fi
        
        echo ""
        if [ -z "$relative_path" ]; then
            echo "  [c] Custom path"
        else
            echo "  [b] Back to parent directory"
        fi
        echo "  [Enter] Use current directory"
        echo ""
        
        # Get user selection
        local choice
        if ! read -t 60 -p "Select option: " choice; then
            echo ""
            print_warning "Timeout reached. Exiting."
            exit 0
        fi
        
        # Handle custom path (only at top level)
        if [ -z "$relative_path" ] && [[ "$choice" =~ ^[cC]$ ]]; then
            read -p "Enter custom source path (relative to $BASE_SOURCE): " SELECTED_SRC_DIR
            return 0
        fi
        
        # Handle back
        if [ -n "$relative_path" ] && [[ "$choice" =~ ^[bB]$ ]]; then
            # Go back one level
            relative_path=$(dirname "$relative_path")
            if [ "$relative_path" = "." ]; then
                relative_path=""
                current_path="$BASE_SOURCE"
            else
                current_path="$BASE_SOURCE/$relative_path"
            fi
            continue
        fi
        
        # Handle Enter (use current directory)
        if [ -z "$choice" ]; then
            SELECTED_SRC_DIR="$relative_path"
            return 0
        fi
        
        # Handle numeric selection
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$index" ]; then
            local selected="${SUBDIRS[$choice]}"
            if [ -z "$relative_path" ]; then
                relative_path="$selected"
            else
                relative_path="$relative_path/$selected"
            fi
            current_path="$BASE_SOURCE/$relative_path"
        else
            print_error "Invalid selection. Please try again."
            sleep 2
        fi
    done
}

# Function to navigate destination directories hierarchically
navigate_dest_directory() {
    local current_path="$BASE_DEST"
    local relative_path=""
    
    while true; do
        clear
        echo ""
        echo "==================================================="
        if [ -z "$relative_path" ]; then
            echo "Select Destination Directory: $BASE_DEST"
        else
            echo "Current Path: $BASE_DEST/$relative_path"
        fi
        echo "==================================================="
        
        # Get immediate subdirectories only
        local index=1
        declare -a SUBDIRS
        
        if [ -d "$current_path" ]; then
            while IFS= read -r dir; do
                SUBDIRS[$index]=$(basename "$dir")
                echo "  [$index] ${SUBDIRS[$index]}"
                ((index++))
            done < <(find "$current_path" -mindepth 1 -maxdepth 1 -type d | sort)
        fi
        
        echo ""
        if [ -z "$relative_path" ]; then
            echo "  [c] Custom path"
        else
            echo "  [b] Back to parent directory"
        fi
        echo "  [Enter] Use current directory"
        echo ""
        
        # Get user selection
        local choice
        if ! read -t 60 -p "Select option: " choice; then
            echo ""
            print_warning "Timeout reached. Exiting."
            exit 0
        fi
        
        # Handle custom path (only at top level)
        if [ -z "$relative_path" ] && [[ "$choice" =~ ^[cC]$ ]]; then
            read -p "Enter custom destination path (relative to $BASE_DEST): " SELECTED_DEST_DIR
            return 0
        fi
        
        # Handle back
        if [ -n "$relative_path" ] && [[ "$choice" =~ ^[bB]$ ]]; then
            # Go back one level
            relative_path=$(dirname "$relative_path")
            if [ "$relative_path" = "." ]; then
                relative_path=""
                current_path="$BASE_DEST"
            else
                current_path="$BASE_DEST/$relative_path"
            fi
            continue
        fi
        
        # Handle Enter (use current directory)
        if [ -z "$choice" ]; then
            SELECTED_DEST_DIR="$relative_path"
            return 0
        fi
        
        # Handle numeric selection
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$index" ]; then
            local selected="${SUBDIRS[$choice]}"
            if [ -z "$relative_path" ]; then
                relative_path="$selected"
            else
                relative_path="$relative_path/$selected"
            fi
            current_path="$BASE_DEST/$relative_path"
        else
            print_error "Invalid selection. Please try again."
            sleep 2
        fi
    done
}

# Recursive hardlinking function
link_recursive() {
    local src_dir="$1"
    local dst_dir="$2"
    
    # Ensure destination directory exists
    if ! mkdir -p "$dst_dir" 2>/dev/null; then
        print_error "Failed to create destination directory: $dst_dir"
        return 1
    fi
    log_verbose "Ensured destination directory exists: $dst_dir"
    
    # Loop through items in source directory
    for item in "$src_dir"/*; do
        # Check if item exists (handles empty directories)
        if [ ! -e "$item" ]; then
            log_verbose "No items found in directory: $src_dir"
            break
        fi
        
        if [ -d "$item" ]; then
            local sub_dir_name=$(basename "$item")
            local dest_sub_dir="$dst_dir/$sub_dir_name"
            log_verbose "Entering subdirectory: $item"
            # Recurse into subdirectory
            link_recursive "$item" "$dest_sub_dir"
        elif [ -f "$item" ]; then
            ((TOTAL_FILES++))
            
            # Check if file is already hardlinked
            if is_already_hardlinked "$item"; then
                ((SKIPPED_FILES++))
                log_verbose "Skipped (already hardlinked): $item -> Link count: $(stat -c %h "$item")"
                continue
            fi
            
            log_verbose "Linking file: $item -> $dst_dir/"
            # Attempt to create hardlink
            if ln -f "$item" "$dst_dir/" 2>/dev/null; then
                ((LINKED_FILES++))
                log_verbose "Successfully linked: $(basename "$item")"
            else
                ((ERROR_FILES++))
                print_error "Failed to link: $(basename "$item")"
            fi
        else
            LOG+="[WARN] Skipped unsupported item: $item\n"
        fi
    done
}

# Main script starts here
clear
echo "=========================================="
echo "  Interactive-Smart-Hardlinker"
echo "=========================================="
echo ""

# Initial timeout prompt
print_info "Starting in 30 seconds... (Press Enter to continue or Ctrl+C to cancel)"
if ! read -t 30 -s; then
    echo ""
    print_warning "No input detected. Exiting."
    exit 0
fi
echo ""

# ===== SOURCE SELECTION =====
navigate_source_directory
SRC_SUBDIR="$SELECTED_SRC_DIR"

# Ask for additional subdirectory
read -p "Add additional subdirectory to source? (press Enter to skip): " SRC_EXTRA_SUBDIR
if [ -n "$SRC_EXTRA_SUBDIR" ]; then
    if [ -z "$SRC_SUBDIR" ]; then
        SRC_SUBDIR="$SRC_EXTRA_SUBDIR"
    else
        SRC_SUBDIR="${SRC_SUBDIR%/}/$SRC_EXTRA_SUBDIR"
    fi
fi

# Normalize and build full source path
SRC_SUBDIR="${SRC_SUBDIR%/}"
SRC_DIR="$BASE_SOURCE/$SRC_SUBDIR"

# Verify source exists
if [ ! -d "$SRC_DIR" ]; then
    print_error "Source directory does not exist: $SRC_DIR"
    exit 1
fi

log_verbose "Configuration: Source directory set to $SRC_DIR"
print_success "Source: $SRC_DIR"
echo ""

# ===== DESTINATION SELECTION =====
navigate_dest_directory
DEST_SUBDIR="$SELECTED_DEST_DIR"

# Ask for additional subdirectory
read -p "Add additional subdirectory to destination? (press Enter to skip): " DEST_EXTRA_SUBDIR
if [ -n "$DEST_EXTRA_SUBDIR" ]; then
    if [ -z "$DEST_SUBDIR" ]; then
        DEST_SUBDIR="$DEST_EXTRA_SUBDIR"
    else
        DEST_SUBDIR="${DEST_SUBDIR%/}/$DEST_EXTRA_SUBDIR"
    fi
fi

# Normalize and build full destination path
DEST_SUBDIR="${DEST_SUBDIR%/}"
DST_DIR="$BASE_DEST/$DEST_SUBDIR"

log_verbose "Configuration: Destination directory set to $DST_DIR"
print_success "Destination: $DST_DIR"
echo ""

# ===== CONFIRMATION =====
echo "=========================================="
echo "Ready to link:"
echo "  FROM: $SRC_DIR"
echo "  TO:   $DST_DIR"
echo "=========================================="
read -p "Continue? [Y/n]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && [ -n "$CONFIRM" ]; then
    print_warning "Operation cancelled."
    exit 0
fi

echo ""
print_info "Starting hardlink operation..."
log_verbose "=========================================="
log_verbose "Starting hardlink operation at $(date)"
log_verbose "=========================================="
echo ""

# Execute the linking
link_recursive "$SRC_DIR" "$DST_DIR"

# Display summary
echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo "  Total files processed: $TOTAL_FILES"
echo -e "  ${GREEN}Successfully linked:${NC}   $LINKED_FILES"
echo -e "  ${YELLOW}Skipped (existing):${NC}    $SKIPPED_FILES"
echo -e "  ${RED}Errors:${NC}                $ERROR_FILES"
echo "=========================================="
echo ""

# Prompt to save log file
SAVE_LOG=$(get_input_with_timeout "Would you like to save the full output log file? [y/N]: " 60)
SAVE_LOG_EXIT=$?

if [ $SAVE_LOG_EXIT -eq 0 ] && [[ "$SAVE_LOG" =~ ^[Yy]$ ]]; then
    # Generate timestamp-based filename
    TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
    LOG_FILENAME="hardlink_log_${TIMESTAMP}.txt"
    
    # Ask for save location
    read -t 60 -p "Enter save location (default: /mnt/user/logs/user scripts/Interactive-Smart-Hardlinker): " SAVE_LOCATION
    
    # Use default if no input or timeout
    if [ -z "$SAVE_LOCATION" ]; then
        SAVE_LOCATION="/mnt/user/logs/user scripts/Interactive-Smart-Hardlinker"
    fi
    
    # Remove trailing slash
    SAVE_LOCATION="${SAVE_LOCATION%/}"
    
    # Create directory if it doesn't exist
    if mkdir -p "$SAVE_LOCATION" 2>/dev/null; then
        FULL_LOG_PATH="$SAVE_LOCATION/$LOG_FILENAME"
        
        # Write log header
        {
            echo "=========================================="
            echo "Hardlink Operation Log"
            echo "=========================================="
            echo "Date: $(date)"
            echo "Source: $SRC_DIR"
            echo "Destination: $DST_DIR"
            echo "=========================================="
            echo ""
            echo -e "$LOG"
            echo ""
            echo "=========================================="
            echo "Summary"
            echo "=========================================="
            echo "Total files processed: $TOTAL_FILES"
            echo "Successfully linked:   $LINKED_FILES"
            echo "Skipped (existing):    $SKIPPED_FILES"
            echo "Errors:                $ERROR_FILES"
            echo "=========================================="
        } > "$FULL_LOG_PATH"
        
        print_success "Log file saved to: $FULL_LOG_PATH"
    else
        print_error "Failed to create log directory: $SAVE_LOCATION"
    fi
elif [ $SAVE_LOG_EXIT -ne 0 ]; then
    echo ""
    print_warning "Timeout reached. Log file not saved."
fi

echo ""

if [ $ERROR_FILES -gt 0 ]; then
    exit 1
else
    print_success "Hardlinking completed successfully!"
    exit 0
fi
