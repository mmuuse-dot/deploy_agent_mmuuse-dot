#!/usr/bin/env bash
# setup_project.sh
# Project Factory for Student Attendance Tracker
# Ogayo - deploy_agent_Ogayo

set -euo pipefail

# Cleanup function (called on SIGINT / Ctrl+C)
cleanup() {
    local exit_code=${1:-1}
    echo ""
    echo "  SIGINT received - cleaning up incomplete project"
    

    if [[ -n "${dir:-}" && -d "$dir" ]]; then
        cd .. || true
        local archive_name="attendance_tracker_${input}_archive_$(date +%Y%m%d_%H%M%S).tar.gz"
        echo "Creating archive: $archive_name"
        tar -czf "$archive_name" "$dir" 2>/dev/null || echo "Warning: archive creation failed"
        echo "Removing incomplete directory: $dir"
        rm -rf "$dir"
        echo "Cleanup complete."
    else
        echo "No partial project directory found to clean up."
    fi

    exit "$exit_code"
}

# Register trap as early as possible
trap 'cleanup 130' INT

# 1. Get project name / suffix
if [[ $# -eq 1 ]]; then
    input="$1"
else
    read -r -p "Enter project suffix (will create attendance_tracker_<suffix>): " input
fi

# Basic input sanitization
input=$(echo "$input" | tr -s '[:space:]' '_' | tr -cd '[:alnum:]_-')
if [[ -z "$input" ]]; then
    echo "Error: Project suffix cannot be empty."
    exit 1
fi

dir="attendance_tracker_${input}"

# Prevent overwriting existing project
if [[ -d "$dir" ]]; then
    echo "Error: Directory '$dir' already exists."
    echo "Please choose a different suffix or remove the existing folder."
    exit 1
fi

# 2. Create directory structure
echo "Creating project: $dir"

mkdir -p "$dir/Helpers" "$dir/reports" || {
    echo "Error: Could not create directories (check permissions)."
    exit 1
}

cd "$dir" || exit 1

# attendance_checker.py
cat > attendance_checker.py << 'EOF'
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)
    
    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")
        
        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])
            
            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100
            
            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."
            
            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
EOF

# Helpers/assets.csv
cat > Helpers/assets.csv << 'EOF'
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
EOF

# Helpers/config.json
cat > Helpers/config.json << 'EOF'
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}

EOF

# reports/reports.log (empty file)
touch reports/reports.log

chmod +x attendance_checker.py 2>/dev/null || true
# 3. Dynamic configuration (thresholds)
echo ""

while true; do
    read -r -p "Would you like to change the attendance thresholds? (y/N): " answer

    case "$answer" in
        y|n)
            break
            ;;
        *)
            echo "Invalid input. Please enter y or n only."
            ;;
    esac
done
if [[ "${answer,,}" == "y" ]]; then
    echo "Current defaults → Warning: 75%, Failure: 50%"
    while true; do
    read -r -p "New Warning threshold (1-100) [75]: " warn_input
    warn=${warn_input:-75}

    if [[ "$warn" =~ ^[0-9]+$ ]] && (( warn >= 1 && warn <= 100 )); then
        break
    else
        echo "Invalid input. Please enter a number between 1 and 100."
    fi
done
read -r -p "New Failure threshold (1-100) [$warn]: " fail_input
while true; do
    read -r -p "New Failure threshold (1-100): " fail

    if [[ "$fail" =~ ^[0-9]+$ ]] && (( fail >= 1 && fail <= 100 )); then
        break
    else
        echo "Invalid input. Please enter a number between 1 and 100."
    fi
done

echo "Failure threshold set to: $fail" 
# Update config.json in-place (using portable sed syntax)
    sed -i.bak "s/\"warning_threshold\": [0-9]*,/\"warning_threshold\": $warn,/" Helpers/config.json
    sed -i.bak "s/\"failure_threshold\": [0-9]*/\"failure_threshold\": $fail/" Helpers/config.json
    rm -f Helpers/config.json.bak

    echo "Updated → Warning: $warn%, Failure: $fail%"
fi

# 4. Health check
echo ""
echo "Performing environment & structure health check..."
health_ok=true

if command -v python3 >/dev/null 2>&1; then
    echo "✓ python3 found ($(python3 --version 2>&1 | head -n1))"
else
    echo "⚠  python3 not found in PATH"
    health_ok=false
fi

# Structure check
errors=()
[[ -f attendance_checker.py ]]    || errors+=("attendance_checker.py missing")
[[ -d Helpers ]]                   || errors+=("Helpers/ directory missing")
[[ -f Helpers/assets.csv ]]        || errors+=("Helpers/assets.csv missing")
[[ -f Helpers/config.json ]]       || errors+=("Helpers/config.json missing")
[[ -d reports ]]                   || errors+=("reports/ directory missing")
[[ -f reports/reports.log ]]       || errors+=("reports/reports.log missing")

if ((${#errors[@]} == 0)); then
    echo "✓ Directory structure is correct"
else
    echo "✗ Structure problems detected:"
    printf '  - %s\n' "${errors[@]}"
    health_ok=false
fi

if $health_ok; then
    echo ""
    echo "Project setup completed successfully ✓"
    echo "You can now run: python3 attendance_checker.py"
    echo ""
    echo "(Press Ctrl+C now to test the archive + cleanup feature)"
    sleep 12
else
    echo ""
    echo "Setup finished with warnings. Review messages above."
fi

exit 0
