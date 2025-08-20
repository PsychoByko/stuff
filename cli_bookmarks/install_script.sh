#!/bin/bash
set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

# Директорії
INSTALL_DIR="$HOME/.local/share/cli-bookmarks"
BIN_DIR="$HOME/.local/bin"

info "Installing CLI Bookmarks for Fedora/GNOME/Wayland..."

# Перевірка залежностей
check_deps() {
    local missing=()
    
    command -v python3 >/dev/null || missing+=("python3")
    command -v fzf >/dev/null || missing+=("fzf")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        info "Install with: sudo dnf install ${missing[*]}"
        exit 1
    fi
    
    # Рекомендація для clipboard - видалено, clipboard не використовується
    success "All dependencies found"
}

# Створення структури
create_structure() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
}

# Встановлення файлів
install_files() {
    # Створюємо основний Python файл
    cat > "$INSTALL_DIR/cli-bookmarks" << 'EOF'
#!/usr/bin/env python3
"""
CLI Bookmarks - спрощений аналог Marker для Fedora/GNOME/Wayland
Вставляє обрану команду безпосередньо в рядок терміналу
"""

import os
import sys
import subprocess
import re
from pathlib import Path

BOOKMARKS_FILE = Path.home() / '.local' / 'share' / 'cli-bookmarks' / 'bookmarks'

def run_fzf(items, prompt, height=15):
    """Запуск fzf для вибору з списку"""
    if not items:
        return None
        
    try:
        result = subprocess.run([
            'fzf',
            '--layout=reverse',
            f'--height={height}',
            f'--prompt={prompt}',
            '--border',
            '--cycle'
        ], input='\n'.join(items), text=True, capture_output=True)
        
        return result.stdout.strip() if result.returncode == 0 else None
        
    except FileNotFoundError:
        print("ERROR: fzf not found! Install with: sudo dnf install fzf")
        sys.exit(1)

def parse_bookmarks():
    """Парсинг файлу закладок по категоріях"""
    if not BOOKMARKS_FILE.exists():
        print(f"ERROR: Bookmarks file not found: {BOOKMARKS_FILE}")
        sys.exit(1)
        
    categories = {}
    current_category = None
    
    with open(BOOKMARKS_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('##'):
                current_category = line[2:].strip()
                categories[current_category] = []
            elif line and not line.startswith('#') and current_category:
                categories[current_category].append(line)
    
    return categories

def clean_command(command):
    """Видалити коментар з команди"""
    return command.split('#')[0].strip()

def main():
    # Парсимо закладки
    categories = parse_bookmarks()
    
    if not categories:
        print("ERROR: No categories found in bookmarks file")
        sys.exit(1)
    
    # Вибираємо категорію
    category_list = sorted(categories.keys())
    selected_category = run_fzf(category_list, "📁 Category: ", height=10)
    
    if not selected_category:
        sys.exit(0)
    
    # Вибираємо команду з категорії
    commands = categories[selected_category]
    if not commands:
        print(f"ERROR: No commands in category: {selected_category}")
        sys.exit(1)
    
    selected_command = run_fzf(commands, f"⚡ {selected_category}: ")
    
    if not selected_command:
        sys.exit(0)
    
    # Очищуємо команду від коментарів
    clean_cmd = clean_command(selected_command)
    
    # Виводимо команду для bash wrapper'а
    print(f"__CLI_BOOKMARKS_COMMAND={clean_cmd}")

if __name__ == '__main__':
    main()
EOF

    # Створюємо wrapper файл
    cat > "$INSTALL_DIR/cli-bookmarks-wrapper.sh" << 'EOF'
#!/bin/bash
# Wrapper для інтеграції cli-bookmarks з bash readline

CLI_BOOKMARKS_DIR="$HOME/.local/share/cli-bookmarks"

# Функція для вставки команди в readline
cli_bookmarks_insert() {
    local output command
    
    # Запускаємо Python скрипт і отримуємо команду
    output=$(python3 "$CLI_BOOKMARKS_DIR/cli-bookmarks" 2>/dev/null)
    
    # Парсимо команду з виводу
    if [[ "$output" =~ __CLI_BOOKMARKS_COMMAND=(.+) ]]; then
        command="${BASH_REMATCH[1]}"
        
        # Вставляємо команду безпосередньо в readline
        READLINE_LINE="$command"
        READLINE_POINT=${#READLINE_LINE}
        
        # Якщо є placeholder'и, позиціонуємо курсор
        if [[ "$command" =~ \{\{ ]]; then
            # Знаходимо позицію після перших {{
            local temp="${command%%\{\{*}"
            READLINE_POINT=$((${#temp} + 2))
        fi
    fi
}

# Експортуємо функцію для використання в bash
export -f cli_bookmarks_insert

# Якщо скрипт викликано напряму (не через binding)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    python3 "$CLI_BOOKMARKS_DIR/cli-bookmarks"
fi
EOF
    
    chmod +x "$INSTALL_DIR/cli-bookmarks"
    chmod +x "$INSTALL_DIR/cli-bookmarks-wrapper.sh"
    
    # Створюємо symlink
    ln -sf "$INSTALL_DIR/cli-bookmarks-wrapper.sh" "$BIN_DIR/cli-bookmarks"
    
    success "Files installed"
}

# Створення файлу закладок
create_bookmarks() {
    local bookmarks_file="$INSTALL_DIR/bookmarks"
    
    if [ -f "$bookmarks_file" ]; then
        info "Bookmarks file already exists, keeping current content"
        return
    fi
    
    cat > "$bookmarks_file" << 'EOF'
##SYSTEM
ps aux | grep {{process}}              # Find process
df -h                                  # Disk usage
free -h                                # Memory usage
systemctl status {{service}}           # Service status
journalctl -fu {{service}}             # Follow logs
systemctl restart {{service}}          # Restart service
lscpu                                  # CPU info
uptime                                 # System uptime

##FILES
find . -name "{{pattern}}" -type f     # Find files
find . -name "{{pattern}}" -type d     # Find directories
grep -rn "{{text}}" {{path}}           # Search in files
du -sh {{directory}}                   # Directory size
chmod +x {{file}}                      # Make executable
ls -la {{path}}                        # List files detailed
tail -f {{logfile}}                    # Follow log file

##COPY
cp -r {{source}} {{dest}}              # Copy directory
cp {{file1}} {{file2}}                 # Copy file
mv {{source}} {{dest}}                 # Move/rename
rsync -av {{source}} {{dest}}          # Sync directories
scp {{file}} {{user}}@{{host}}:{{path}} # Copy over SSH
 
##NETWORK
ping -c 4 {{hostname}}                 # Ping host
wget {{url}}                           # Download file
curl -X GET {{url}}                    # HTTP request
ss -tlnp | grep {{port}}               # Check port
netstat -tlnp | grep {{port}}          # Port check (legacy)
ssh {{user}}@{{host}}                  # SSH connect

##GIT
git status                             # Repository status
git add {{files}}                      # Stage files
git commit -m "{{message}}"            # Commit
git push origin {{branch}}             # Push to branch
git pull origin {{branch}}             # Pull from branch
git checkout {{branch}}                # Switch branch
git log --oneline -10                  # Recent commits
git diff {{file}}                      # Show changes

##DOCKER
docker ps                              # Running containers
docker ps -a                           # All containers
docker images                          # List images
docker exec -it {{container}} bash     # Enter container
docker logs -f {{container}}           # Follow logs
docker build -t {{tag}} .              # Build image
docker run -d --name {{name}} {{image}} # Run container

##DNF
sudo dnf update                        # Update system
sudo dnf install {{package}}           # Install package
sudo dnf remove {{package}}            # Remove package
sudo dnf search {{term}}               # Search packages
dnf list installed | grep {{package}} # Check if installed
sudo dnf autoremove                    # Remove unused packages

##GPU
lspci | grep VGA                       # GPU info
nvidia-smi                             # NVIDIA status
glxinfo | grep "OpenGL"                # OpenGL info
vulkaninfo | grep "GPU"                # Vulkan info

##MONITORING
htop                                   # Process monitor
iotop                                  # I/O monitor
nethogs                               # Network usage
watch -n {{seconds}} {{command}}      # Repeat command
EOF

    success "Example bookmarks created: $bookmarks_file"
}

# Налаштування bash binding
setup_bash_binding() {
    local bashrc="$HOME/.bashrc"
    
    if grep -q "cli_bookmarks_insert" "$bashrc" 2>/dev/null; then
        info "Bash binding already configured"
        return
    fi
    
    cat >> "$bashrc" << 'EOF'

# CLI Bookmarks - Ctrl+Space hotkey
if [ -f "$HOME/.local/share/cli-bookmarks/cli-bookmarks-wrapper.sh" ]; then
    source "$HOME/.local/share/cli-bookmarks/cli-bookmarks-wrapper.sh"
    bind -x '"\C-@": cli_bookmarks_insert'
fi
EOF
    
    success "Ctrl+Space binding added to ~/.bashrc"
}

# Перевірка PATH
check_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        warn "~/.local/bin not in PATH"
        info "Add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# Головна функція встановлення
main() {
    check_deps
    create_structure
    install_files
    create_bookmarks
    setup_bash_binding
    check_path
    
    success "CLI Bookmarks installed successfully!"
    info "Restart terminal or run: source ~/.bashrc"
    info "Press Ctrl+Space to open bookmarks"
    info "Commands will be inserted directly into terminal line"
    info "Edit bookmarks: $INSTALL_DIR/bookmarks"
}

main
