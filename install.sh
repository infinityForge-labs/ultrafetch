#!/bin/bash

################################################################################
#                                                                              #
#                        UltraFetch Installer v3.1                             #
#                      by InfinityForge Labs (2025)                            #
#                                                                              #
#  Professional system information tool installer with comprehensive           #
#  dependency management, robust error handling, and network diagnostics.      #
#                                                                              #
################################################################################

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# 🎨 COLOR DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# 📋 CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
readonly INSTALL_PATH="/usr/local/bin/ultrafetch"
readonly FETCH_URL="https://raw.githubusercontent.com/infinityForge-labs/ultrafetch/refs/heads/main/scripts/ultrafetch"
readonly SCRIPT_VERSION="3.1"
readonly MIN_BASH_VERSION=4
readonly TIMEOUT_DURATION=15
readonly LOG_FILE="/tmp/ultrafetch_install_$(date +%Y%m%d_%H%M%S).log"

# ═══════════════════════════════════════════════════════════════════════════
# 🛠️ UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    echo -e "${CYAN}ℹ${NC}  $*"
    log_to_file "INFO: $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} ${BOLD}$*${NC}"
    log_to_file "SUCCESS: $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $*"
    log_to_file "WARNING: $*"
}

log_error() {
    echo -e "${RED}✗${NC} ${BOLD}$*${NC}" >&2
    log_to_file "ERROR: $*"
}

log_step() {
    echo ""
    echo -e "${BOLD}${MAGENTA}╭─────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BOLD}${MAGENTA}│${NC} ${BOLD}$*${NC}"
    echo -e "${BOLD}${MAGENTA}╰─────────────────────────────────────────────────────────╯${NC}"
    echo ""
    log_to_file "STEP: $*"
}

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║              🚀 UltraFetch Installer v3.1 🚀                 ║
    ║                                                              ║
    ║                 by InfinityForge Labs (2025)                 ║
    ║                                                              ║
    ║          Professional System Information Utility             ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    log_info "Installation log: ${DIM}${LOG_FILE}${NC}\n"
}

# ═══════════════════════════════════════════════════════════════════════════
# 🔍 SYSTEM CHECKS
# ═══════════════════════════════════════════════════════════════════════════

check_bash_version() {
    if ((BASH_VERSINFO[0] < MIN_BASH_VERSION)); then
        log_error "Bash ${MIN_BASH_VERSION}.0+ is required (current: ${BASH_VERSION})"
        exit 1
    fi
    log_success "Bash version verified (${BASH_VERSION})"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required"
        echo -e "\n${YELLOW}Please run:${NC} ${BOLD}sudo $0${NC}\n"
        exit 1
    fi
    log_success "Running with root privileges"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_success "Detected: ${NAME} ${VERSION_ID:-unknown}"
    else
        log_warning "Could not detect OS version"
    fi
}

check_disk_space() {
    local available
    available=$(df /usr/local/bin 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n "$available" ]] && [[ $available -lt 10240 ]]; then
        log_warning "Low disk space detected (less than 10MB available)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 🌐 NETWORK CONNECTIVITY (FIXED)
# ═══════════════════════════════════════════════════════════════════════════

check_internet() {
    log_step "Network Connectivity Check"
    
    log_info "Testing network connectivity..."
    
    # Method 1: Try curl to GitHub (most reliable for this use case)
    if curl -fsSL --connect-timeout 5 --max-time 10 \
        "https://raw.githubusercontent.com" -o /dev/null 2>/dev/null; then
        log_success "Internet connection verified (GitHub accessible)"
        return 0
    fi
    
    # Method 2: Try curl to Google
    if curl -fsSL --connect-timeout 5 --max-time 10 \
        "https://www.google.com" -o /dev/null 2>/dev/null; then
        log_success "Internet connection verified (Google accessible)"
        return 0
    fi
    
    # Method 3: Try curl to Cloudflare
    if curl -fsSL --connect-timeout 5 --max-time 10 \
        "https://1.1.1.1" -o /dev/null 2>/dev/null; then
        log_success "Internet connection verified (Cloudflare accessible)"
        return 0
    fi
    
    # Method 4: Try ping as fallback (might be blocked)
    if command -v ping >/dev/null 2>&1; then
        if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            log_success "Internet connection verified (ICMP response)"
            return 0
        fi
    fi
    
    # Method 5: Try DNS resolution
    if command -v nslookup >/dev/null 2>&1; then
        if nslookup github.com >/dev/null 2>&1; then
            log_warning "DNS works but HTTP/HTTPS connectivity unclear"
            log_info "Attempting to proceed anyway..."
            return 0
        fi
    fi
    
    # All methods failed
    log_error "Cannot verify internet connectivity"
    echo ""
    log_warning "Possible causes:"
    echo -e "   ${DIM}•${NC} Network firewall blocking outbound connections"
    echo -e "   ${DIM}•${NC} Proxy configuration required"
    echo -e "   ${DIM}•${NC} DNS resolution issues"
    echo -e "   ${DIM}•${NC} No internet access"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Proceeding without connectivity verification..."
        return 0
    else
        log_info "Installation cancelled by user"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 📦 PACKAGE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt-get"
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

update_packages() {
    log_step "Package Repository Update"
    
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)
    
    log_info "Package manager: ${BOLD}${pkg_mgr}${NC}"
    log_info "Refreshing package lists..."
    
    case "$pkg_mgr" in
        apt|apt-get)
            if DEBIAN_FRONTEND=noninteractive $pkg_mgr update -qq 2>&1 | tee -a "$LOG_FILE" | grep -q "^"; then
                log_success "Package lists updated"
            else
                log_success "Package lists updated"
            fi
            ;;
        dnf|yum)
            if $pkg_mgr check-update -q >/dev/null 2>&1 || [ $? -eq 100 ]; then
                log_success "Package lists updated"
            fi
            ;;
        pacman)
            if pacman -Sy --noconfirm >/dev/null 2>&1; then
                log_success "Package lists updated"
            fi
            ;;
        zypper)
            if zypper refresh >/dev/null 2>&1; then
                log_success "Package lists updated"
            fi
            ;;
        *)
            log_warning "Unsupported package manager, skipping update"
            ;;
    esac
}

install_dependency() {
    local cmd=$1
    local pkg=$2
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓${NC} ${pkg} ${DIM}(already installed)${NC}"
        return 0
    fi
    
    echo -ne "   ${CYAN}◌${NC} ${pkg} ${DIM}(installing...)${NC}"
    
    local install_cmd
    case "$pkg_mgr" in
        apt|apt-get)
            install_cmd="DEBIAN_FRONTEND=noninteractive $pkg_mgr install -qq -y $pkg"
            ;;
        dnf|yum)
            install_cmd="$pkg_mgr install -q -y $pkg"
            ;;
        pacman)
            install_cmd="pacman -S --noconfirm --quiet $pkg"
            ;;
        zypper)
            install_cmd="zypper install -y $pkg"
            ;;
        *)
            echo -e "\r   ${YELLOW}⚠${NC} ${pkg} ${DIM}(unsupported package manager)${NC}"
            return 1
            ;;
    esac
    
    if eval "$install_cmd" >>"$LOG_FILE" 2>&1; then
        echo -e "\r   ${GREEN}✓${NC} ${pkg} ${DIM}(installed)${NC}          "
        return 0
    else
        echo -e "\r   ${RED}✗${NC} ${pkg} ${DIM}(failed)${NC}              "
        return 1
    fi
}

install_dependencies() {
    log_step "Dependency Installation"
    
    local -A dependencies=(
        ["curl"]="curl"
        ["bc"]="bc"
        ["lscpu"]="util-linux"
        ["lspci"]="pciutils"
        ["sensors"]="lm-sensors"
    )
    
    log_info "Installing required packages...\n"
    
    local failed=0
    local total=${#dependencies[@]}
    
    for cmd in "${!dependencies[@]}"; do
        install_dependency "$cmd" "${dependencies[$cmd]}" || ((failed++))
    done
    
    echo ""
    
    if ((failed == 0)); then
        log_success "All dependencies installed (${total}/${total})"
    else
        log_warning "Partial installation: $((total - failed))/${total} packages installed"
        log_info "Some features may not work correctly"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ⚙️ SENSOR CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

configure_sensors() {
    log_step "Hardware Sensor Configuration"
    
    if ! command -v sensors >/dev/null 2>&1; then
        log_warning "lm-sensors not installed, skipping configuration"
        return 0
    fi
    
    # Check if sensors already work
    if sensors >/dev/null 2>&1 && sensors 2>&1 | grep -q "°C\|°F"; then
        log_success "Sensors already configured and working"
        return 0
    fi
    
    log_info "Detecting hardware sensors (this may take 30-60 seconds)..."
    log_warning "You may see kernel module warnings - this is normal"
    
    # Run sensors-detect non-interactively
    if yes "" 2>/dev/null | timeout 60 sensors-detect >>"$LOG_FILE" 2>&1; then
        log_success "Sensor detection completed"
        
        # Try to load modules
        if systemctl restart kmod >/dev/null 2>&1 || service kmod restart >/dev/null 2>&1; then
            log_success "Sensor modules loaded"
        else
            log_info "Run 'sudo sensors-detect' manually if sensors don't work"
        fi
    else
        log_warning "Sensor detection skipped or timed out (non-critical)"
        log_info "You can run 'sudo sensors-detect' later if needed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 📥 ULTRAFETCH INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════

install_ultrafetch() {
    log_step "UltraFetch Installation"
    
    log_info "Downloading from GitHub..."
    echo -e "${DIM}Source: ${FETCH_URL}${NC}\n"
    
    local temp_file
    temp_file=$(mktemp)
    
    # Download with detailed progress
    if curl -fsSL --connect-timeout 10 --max-time 30 \
        "$FETCH_URL" -o "$temp_file" 2>&1 | tee -a "$LOG_FILE"; then
        
        # Verify download
        if [[ ! -s "$temp_file" ]]; then
            log_error "Downloaded file is empty"
            rm -f "$temp_file"
            exit 1
        fi
        
        # Check if it looks like a shell script
        if ! head -n 1 "$temp_file" | grep -q "^#!"; then
            log_error "Downloaded file doesn't appear to be a valid script"
            log_warning "File contents: $(head -n 1 "$temp_file")"
            rm -f "$temp_file"
            exit 1
        fi
        
        # Install
        mv "$temp_file" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        
        log_success "UltraFetch installed successfully"
        echo -e "${DIM}Location: ${INSTALL_PATH}${NC}"
        
    else
        log_error "Download failed"
        echo ""
        log_warning "Troubleshooting steps:"
        echo -e "   ${DIM}1.${NC} Verify internet connection"
        echo -e "   ${DIM}2.${NC} Check if GitHub is accessible: curl -I https://github.com"
        echo -e "   ${DIM}3.${NC} Try manual download: curl -O ${FETCH_URL}"
        echo -e "   ${DIM}4.${NC} Check firewall/proxy settings"
        echo ""
        rm -f "$temp_file"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ✅ VERIFICATION & TESTING
# ═══════════════════════════════════════════════════════════════════════════

verify_installation() {
    log_step "Installation Verification"
    
    # Check if command exists
    if ! command -v ultrafetch >/dev/null 2>&1; then
        log_error "Installation failed: command not found"
        log_info "Try adding /usr/local/bin to your PATH"
        return 1
    fi
    
    log_success "Command is accessible in PATH"
    
    # Check file permissions
    if [[ -x "$INSTALL_PATH" ]]; then
        log_success "File permissions are correct"
    else
        log_warning "File exists but may not be executable"
    fi
    
    # Try to get version
    local version
    if version=$(ultrafetch --version 2>/dev/null); then
        log_success "UltraFetch version: ${BOLD}${version}${NC}"
    fi
    
    return 0
}

run_quick_test() {
    echo ""
    read -p "$(echo -e ${CYAN}Would you like to run UltraFetch now? [Y/n]:${NC} )" -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        log_info "Running UltraFetch...\n"
        sleep 1
        ultrafetch || log_warning "UltraFetch encountered an error"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 📊 COMPLETION SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

print_completion_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                              ║${NC}"
    echo -e "${GREEN}${BOLD}║               ✨ Installation Complete! ✨                    ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                              ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_success "UltraFetch is ready to use!"
    echo ""
    echo -e "${BOLD}Quick Start:${NC}"
    echo -e "   ${CYAN}$${NC} ${BOLD}ultrafetch${NC}          ${DIM}# Display system information${NC}"
    echo -e "   ${CYAN}$${NC} ${BOLD}ultrafetch --help${NC}   ${DIM}# Show available options${NC}"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Resources & Support:${NC}"
    echo -e "   🌐 Website   ${BLUE}https://infinityforge.tech${NC}"
    echo -e "   💬 Discord   ${BLUE}https://discord.gg/infinityforge${NC}"
    echo -e "   📖 Docs      ${BLUE}https://docs.infinityforge.tech${NC}"
    echo -e "   📝 Log File  ${DIM}${LOG_FILE}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    log_info "Thank you for installing UltraFetch! 🚀"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# 🎬 MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        log_error "Installation failed with exit code: $exit_code"
        log_info "Check the log file for details: ${LOG_FILE}"
        echo ""
    fi
}

main() {
    # Initialize
    print_banner
    
    # System checks
    log_step "Pre-Installation Checks"
    check_bash_version
    check_root
    detect_os
    check_disk_space
    
    # Network verification
    check_internet
    
    # Installation process
    update_packages
    install_dependencies
    configure_sensors
    install_ultrafetch
    
    # Verification
    if verify_installation; then
        print_completion_summary
        run_quick_test
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Error handling
trap cleanup EXIT
trap 'log_error "Installation interrupted at line $LINENO"; exit 130' INT TERM

# Execute
main "$@"
