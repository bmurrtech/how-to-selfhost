#!/bin/bash
# WSL2 + GitHub CLI (gh) HTTPS Auth Setup Script
# Intelligently checks prerequisites and configures wslview to open Windows default browser for OAuth

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running in WSL2
check_wsl() {
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        success "WSL2 detected"
        return 0
    else
        error "This script is designed for WSL2. Exiting."
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed (Debian/Ubuntu)
package_installed() {
    dpkg -l | grep -q "^ii  $1 " 2>/dev/null
}

# Detect shell config file
detect_shell_config() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        echo "$HOME/.bashrc"
    else
        echo "$HOME/.bashrc"  # Default fallback
    fi
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    local missing=()
    
    # Check wslview (from wslu package)
    if ! command_exists wslview; then
        missing+=("wslu")
    else
        success "wslview is installed (from wslu)"
    fi
    
    # Check gh
    if ! command_exists gh; then
        missing+=("gh")
    else
        success "GitHub CLI (gh) is installed"
        # Check gh version
        local gh_version
        gh_version=$(gh --version 2>/dev/null | head -n1 || echo "unknown")
        info "  Version: $gh_version"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warning "Missing prerequisites: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Install missing prerequisites
install_prerequisites() {
    info "Installing missing prerequisites..."
    
    local to_install=()
    
    if ! command_exists wslview; then
        to_install+=("wslu")
    fi
    
    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Updating package list..."
        sudo apt update
        
        info "Installing: ${to_install[*]}"
        info "  (wslu provides wslview, which opens URLs in your Windows default browser)"
        sudo apt install -y "${to_install[@]}"
        
        # Verify wslview is now available
        if command_exists wslview; then
            success "wslview installed successfully"
        else
            error "wslview installation failed"
            return 1
        fi
    else
        success "All prerequisites already installed"
    fi
}

# Configure gh to use wslview
configure_gh_browser() {
    info "Configuring GitHub CLI to use wslview (Windows default browser)..."
    
    # Check current gh browser setting
    local current_gh_browser
    current_gh_browser=$(gh config get browser 2>/dev/null || echo "")
    
    if [[ "$current_gh_browser" == "wslview" ]]; then
        success "GitHub CLI already configured to use wslview"
    else
        if [[ -n "$current_gh_browser" ]]; then
            info "Current gh browser setting: $current_gh_browser"
            info "Updating to wslview..."
        else
            info "Setting gh browser to wslview..."
        fi
        
        gh config set browser wslview
        
        # Verify
        local new_gh_browser
        new_gh_browser=$(gh config get browser 2>/dev/null || echo "")
        if [[ "$new_gh_browser" == "wslview" ]]; then
            success "GitHub CLI configured to use wslview"
        else
            warning "Could not verify gh browser configuration"
        fi
    fi
}

# Check and configure BROWSER environment variable
configure_browser_env() {
    info "Configuring BROWSER environment variable..."
    
    local shell_config
    shell_config=$(detect_shell_config)
    
    # Check if BROWSER is already set in shell config
    if grep -q "^export BROWSER=" "$shell_config" 2>/dev/null; then
        local current_browser
        current_browser=$(grep "^export BROWSER=" "$shell_config" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [[ "$current_browser" == "wslview" ]]; then
            success "BROWSER already set to wslview in $shell_config"
        else
            info "BROWSER is set to '$current_browser', updating to wslview..."
            # Remove old BROWSER export
            sed -i '/^export BROWSER=/d' "$shell_config"
            echo 'export BROWSER=wslview' >> "$shell_config"
            success "BROWSER updated to wslview in $shell_config"
        fi
    else
        info "Adding BROWSER=wslview to $shell_config"
        echo '' >> "$shell_config"
        echo '# GitHub CLI browser configuration (opens Windows default browser)' >> "$shell_config"
        echo 'export BROWSER=wslview' >> "$shell_config"
        success "BROWSER added to $shell_config"
    fi
    
    # Export for current session
    export BROWSER=wslview
    success "BROWSER set to wslview for current session"
}

# Check GitHub authentication status
check_gh_auth() {
    info "Checking GitHub authentication status..."
    
    if gh auth status >/dev/null 2>&1; then
        success "GitHub CLI is authenticated"
        gh auth status
        return 0
    else
        warning "GitHub CLI is not authenticated"
        return 1
    fi
}

# Run gh auth login
run_gh_auth_login() {
    info "Starting GitHub authentication..."
    warning "This will open a browser for OAuth. If running headless, you'll get a URL to paste."
    
    if gh auth login; then
        success "GitHub authentication completed"
        return 0
    else
        error "GitHub authentication failed"
        return 1
    fi
}

# Check and configure Git credential helper
configure_git_credential_helper() {
    info "Configuring Git credential helper..."
    
    local current_helper
    current_helper=$(git config --global --get credential.helper 2>/dev/null || echo "")
    
    if [[ "$current_helper" == "!gh auth git-credential" ]]; then
        success "Git credential helper already configured"
    else
        if [[ -n "$current_helper" ]]; then
            info "Current credential helper: $current_helper"
            warning "This will be replaced with gh auth git-credential"
        fi
        
        info "Setting Git credential helper to use gh..."
        gh auth setup-git
        
        # Verify
        local new_helper
        new_helper=$(git config --global --get credential.helper 2>/dev/null || echo "")
        if [[ "$new_helper" == "!gh auth git-credential" ]]; then
            success "Git credential helper configured"
        else
            warning "Could not verify Git credential helper configuration"
        fi
    fi
}

# Test authentication
test_auth() {
    info "Testing authentication..."
    
    # Test gh
    if gh auth status >/dev/null 2>&1; then
        success "GitHub CLI authentication works"
    else
        error "GitHub CLI authentication test failed"
        return 1
    fi
    
    # Test git (if in a git repo)
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local remote_url
        remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
        
        if [[ -n "$remote_url" ]]; then
            info "Testing Git remote access..."
            if git ls-remote --exit-code origin >/dev/null 2>&1; then
                success "Git remote access works"
            else
                warning "Git remote access test failed (may be expected if repo doesn't exist)"
            fi
        fi
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "WSL2 GitHub CLI Auth Setup"
    echo "=========================================="
    echo ""
    
    # Check WSL
    check_wsl
    
    # Check prerequisites
    if ! check_prerequisites; then
        echo ""
        info "Some prerequisites are missing. Installing..."
        install_prerequisites
        echo ""
        
        # Re-check after installation
        if ! check_prerequisites; then
            error "Failed to install all prerequisites"
            exit 1
        fi
    fi
    
    echo ""
    
    # Configure gh to use wslview
    configure_gh_browser
    
    echo ""
    
    # Configure BROWSER environment variable
    configure_browser_env
    
    echo ""
    
    # Check GitHub auth
    local needs_auth=false
    if ! check_gh_auth; then
        needs_auth=true
    fi
    
    echo ""
    
    # Run auth if needed
    if [[ "$needs_auth" == "true" ]]; then
        if run_gh_auth_login; then
            echo ""
        else
            error "Authentication failed. Please run 'gh auth login' manually."
            exit 1
        fi
    fi
    
    # Configure Git credential helper
    configure_git_credential_helper
    
    echo ""
    
    # Test everything
    test_auth
    
    echo ""
    echo "=========================================="
    success "Setup complete!"
    echo "=========================================="
    echo ""
    info "Next steps:"
    echo "  1. Reload your shell: source $(detect_shell_config)"
    echo "  2. Test: git push origin main"
    echo ""
    success "wslview will open your Windows default browser with all your extensions and saved settings!"
    info "If the browser doesn't open automatically, gh will show you a URL and code to paste."
    echo ""
}

# Run main function
main "$@"
