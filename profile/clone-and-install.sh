#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Array of repositories
declare -a repos=(
    "mfe-user-journey-landing-page|git@github.com:Ngx-Workshop/mfe-user-journey-landing-page.git"
    "mfe-shell-admin|git@github.com:Ngx-Workshop/mfe-shell-admin.git"
    "mfe-structural-footer|git@github.com:Ngx-Workshop/mfe-structural-footer.git"
    "mfe-shell-workshop|git@github.com:Ngx-Workshop/mfe-shell-workshop.git"
    "mfe-structural-navigation|git@github.com:Ngx-Workshop/mfe-structural-navigation.git"
    "service-mfe-orchestrator|git@github.com:Ngx-Workshop/service-mfe-orchestrator.git"
    "mfe-structural-header|git@github.com:Ngx-Workshop/mfe-structural-header.git"
    "ngx-theme-picker|git@github.com:Ngx-Workshop/ngx-theme-picker.git"
    "service-bff-ngx-workshop|git@github.com:Ngx-Workshop/service-bff-ngx-workshop.git"
    "seed-mfe-remote|git@github.com:Ngx-Workshop/seed-mfe-remote.git"
    "ngx-local-storage-broker|git@github.com:Ngx-Workshop/ngx-local-storage-broker.git"
    "nginx-ngx-workshop.io|git@github.com:Ngx-Workshop/nginx-ngx-workshop.io.git"
    "service-auth|git@github.com:Ngx-Workshop/service-auth.git"
    "app-authentication|git@github.com:Ngx-Workshop/app-authentication.git"
)

# Counters for summary
total_repos=${#repos[@]}
successful_clones=0
successful_installs=0
failed_clones=0
failed_installs=0

echo "================================================="
echo "  NGX Workshop Repository Clone & Install Script"
echo "================================================="
echo ""
print_status "Starting clone and install process for $total_repos repositories..."
echo ""

# Process each repository
for repo_info in "${repos[@]}"; do
    # Split the repo info into name and URL
    IFS='|' read -r name url <<< "$repo_info"

    echo "----------------------------------------"
    print_status "Processing: $name"
    echo "----------------------------------------"

    # Check if directory already exists
    if [ -d "$name" ]; then
        print_warning "Directory '$name' already exists. Skipping clone..."
        cd "$name" || continue
    else
        # Clone the repository
        print_status "Cloning $name..."
        if git clone "$url" "$name"; then
            print_success "Successfully cloned $name"
            ((successful_clones++))
            cd "$name" || continue
        else
            print_error "Failed to clone $name"
            ((failed_clones++))
            echo ""
            continue
        fi
    fi

    # Check if package.json exists
    if [ -f "package.json" ]; then
        print_status "Installing npm dependencies for $name..."
        if npm install; then
            print_success "Successfully installed dependencies for $name"
            ((successful_installs++))
        else
            print_error "Failed to install dependencies for $name"
            ((failed_installs++))
        fi
    else
        print_warning "No package.json found in $name. Skipping npm install."
    fi

    # Go back to parent directory
    cd ..
    echo ""
done

# Print summary
echo "================================================="
echo "                    SUMMARY"
echo "================================================="
echo "Total repositories: $total_repos"
echo ""
echo "Clone Results:"
echo "  ✅ Successful: $successful_clones"
echo "  ❌ Failed: $failed_clones"
echo ""
echo "NPM Install Results:"
echo "  ✅ Successful: $successful_installs"
echo "  ❌ Failed: $failed_installs"
echo ""

if [ $failed_clones -eq 0 ] && [ $failed_installs -eq 0 ]; then
    print_success "All operations completed successfully! 🎉"
else
    if [ $failed_clones -gt 0 ] || [ $failed_installs -gt 0 ]; then
        print_warning "Some operations failed. Please check the output above for details."
    fi
fi

echo "================================================="
