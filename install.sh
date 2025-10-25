#!/bin/bash

################################################################################
#                                                                              #
#                        UltraFetch Installer v3.0                             #
#                      by InfinityForge Labs (2025)                            #
#                                                                              #
#  A professional system information tool installer with comprehensive         #
#  dependency management and error handling.                                   #
#                                                                              #
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ═══════════════════════════════════════════════════════════════════════════
# 🎨 COLOR DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'  # No Color

# ═══════════════════════════════════════════════════════════════════════════
# 📋 CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
readonly INSTALL_PATH="/usr/local/bin/ultrafetch"
readonly FETCH_URL="https://github.com/infinityForge-labs/ultrafetch/scripts/ultrafetch"
readonly SCRIPT_VERSION="1.0"
readonly MIN_BASH_VERSION=4

# ═══════════════════════════════════════════════════════════════════════════
# 🛠️ UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

# Print formatted log messages
log_info() {
    echo -e "${CYAN}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

log_step() {
    echo -e "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔹 $*${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║            🚀 UltraFetch Installer v3.0 🚀               ║
    ║                                                          ║
    ║              by InfinityForge Labs (2025)                ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Check if script is running with root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo privileges."
        log_info "Please run: sudo $0"
        exit 1
    fi
}

# Verify bash version
check_bash_version() {
    if ((BASH_VERSINFO[0] < MIN_BASH_VERSION)); then
        log_error "Bash version ${MIN_BASH_VERSION}.0 or higher is required."
        log_error "Current version: ${BASH_VERSION}"
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_error "No internet connection detected."
        log_warning "Please check your network connection and try again."
        exit 1
    fi
    log_success "Internet connection verified."
}

# ═══════════════════════════════════════════════════════════════════════════
# 📦 PACKAGE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════

# Update system package lists
update_packages() {
    log_step "Updating Package Lists"
    log_info "Refreshing package repository information..."
    
    if apt update -y >/dev/null 2>&1; then
        log_success "Package lists updated successfully."
    else
        log_error "Failed to update package lists."
        log_warning "Check your internet connection or repository configuration."
        exit 1
    fi
}

# Install a single dependency
install_dependency() {
    local cmd=$1
    local pkg=$2
    
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "${pkg} is already installed. ✓"
        return 0
    fi
    
    log_info "Installing ${pkg}..."
    
    if apt install -y "$pkg" >/dev/null 2>&1; then
        log_success "${pkg} installed successfully."
    else
        log_error "Failed to install ${pkg}."
        log_warning "Installation may be incomplete."
        return 1
    fi
}

# Install all required dependencies
install_dependencies() {
    log_step "Installing Dependencies"
    
    local -A dependencies=(
        ["curl"]="curl"
        ["bc"]="bc"
        ["lscpu"]="util-linux"
        ["lspci"]="pciutils"
        ["sensors"]="lm-sensors"
    )
    
    local failed=0
    
    for cmd in "${!dependencies[@]}"; do
        install_dependency "$cmd" "${dependencies[$cmd]}" || ((failed++))
    done
    
    if ((failed > 0)); then
        log_warning "${failed} dependencies failed to install."
    else
        log_success "All dependencies installed successfully! 🎉"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ⚙️ SENSOR CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

# Configure hardware sensors
configure_sensors() {
    log_step "Configuring Hardware Sensors"
    
    if sensors >/dev/null 2>&1; then
        log_success "Sensors are already configured."
        return 0
    fi
    
    log_info "Running automatic sensor detection..."
    log_warning "This may take a moment..."
    
    if yes "" | sensors-detect >/dev/null 2>&1; then
        log_success "Sensor detection completed successfully."
        
        # Load sensor modules
        if systemctl restart kmod >/dev/null 2>&1 || service kmod restart >/dev/null 2>&1; then
            log_success "Sensor modules loaded."
        fi
    else
        log_warning "Sensor detection encountered issues (non-critical)."
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 📥 ULTRAFETCH INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════

# Download and install UltraFetch
install_ultrafetch() {
    log_step "Downloading UltraFetch"
    
    log_info "Fetching UltraFetch from remote server..."
    log_info "Source: ${FETCH_URL}"
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    
    # Download with progress
    if curl -fsSL --connect-timeout 10 --max-time 30 "$FETCH_URL" -o "$temp_file"; then
        log_success "Download completed successfully."
        
        # Verify file is not empty
        if [[ ! -s "$temp_file" ]]; then
            log_error "Downloaded file is empty."
            rm -f "$temp_file"
            exit 1
        fi
        
        # Move to installation path
        mv "$temp_file" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        
        log_success "UltraFetch installed to: ${INSTALL_PATH}"
    else
        log_error "Download failed."
        log_warning "Possible causes:"
        log_warning "  • Network connectivity issues"
        log_warning "  • Invalid URL or server unavailable"
        log_warning "  • Firewall blocking the connection"
        rm -f "$temp_file"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ✅ VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════

# Verify installation success
verify_installation() {
    log_step "Verifying Installation"
    
    if command -v ultrafetch >/dev/null 2>&1; then
        log_success "UltraFetch is properly installed and accessible! 🎉"
        
        # Show version if available
        if ultrafetch --version >/dev/null 2>&1; then
            log_info "Version: $(ultrafetch --version 2>/dev/null || echo 'N/A')"
        fi
        
        return 0
    else
        log_error "Installation verification failed."
        log_error "UltraFetch command not found in PATH."
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 🎬 MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    
    # Pre-flight checks
    check_bash_version
    check_root
    check_internet
    
    # Installation process
    update_packages
    install_dependencies
    configure_sensors
    install_ultrafetch
    verify_installation
    
    # Success message
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}║          ✨ Installation Complete! ✨                     ║${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    log_success "UltraFetch is ready to use!"
    log_info "Run ${YELLOW}ultrafetch${NC} to view your system information."
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📌 Resources:${NC}"
    echo -e "   🌐 Website:  ${BLUE}https://infinityforge.tech${NC}"
    echo -e "   💬 Discord:  ${BLUE}https://discord.gg/infinityforge${NC}"
    echo -e "   📖 Docs:     ${BLUE}https://docs.infinityforge.tech${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    log_info "Thank you for installing UltraFetch! 🙏"
}

# Trap errors and cleanup
trap 'log_error "Installation failed at line $LINENO. Exiting..."; exit 1' ERR

# Execute main function
main "$@"
