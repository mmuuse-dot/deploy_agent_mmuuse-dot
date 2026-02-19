# Project Factory – Student Attendance Tracker Bootstrap

The Power of Infrastructure as Code (IaC) 
Automating project setup with shell scripting


1. Clone the repository

   bash
   git clone https://github.com/mmuuse-dot/deploy_agent_mmuuse-dot.git
   cd deploy_agent_mmuuse-dot
 
 What this project does

This repository contains a "Project Factory" — a single Bash script ('setup_project.sh') that automatically:

1. Asks for a project identifier  
2. Creates a folder named 'attendance_tracker_<identifier>'
3. Sets up the correct directory structure with all required files
4. Let the user optionally customize attendance warning/failure thresholds
5. Updates `config.json` in-place using 'sed'
6. Performs a basic health check (is `python3` available?)
7. Gracefully handles Ctrl+C ( SIGINT received - cleaning up incomplete project):  
   - Archive whatever was created so far  
   -  Cleans up the incomplete project
 # Final folder structure created by the script
 attendance_tracker_1_
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json          
└── reports/
└── reports.log
# Run the script
./setup_project.sh
