#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_question() {
    echo -e "${BLUE}[INPUT]${NC} $1"
}

# Function to check if GitHub CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first:"
        echo "  brew install gh"
        echo "  or visit: https://cli.github.com/"
        exit 1
    fi

    # Check if user is authenticated
    if ! gh auth status &> /dev/null; then
        print_error "You need to authenticate with GitHub CLI first:"
        echo "  gh auth login"
        exit 1
    fi
}

# Function to prompt for MFE name
get_mfe_name() {
    while true; do
        print_question "Enter the name of the micro frontend (without prefix):"
        read -r mfe_name

        if [[ -z "$mfe_name" ]]; then
            print_error "MFE name cannot be empty. Please try again."
            continue
        fi

        # Remove any spaces and convert to lowercase with hyphens
        mfe_name=$(echo "$mfe_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

        if [[ -z "$mfe_name" ]]; then
            print_error "Invalid MFE name. Please use only letters, numbers, and hyphens."
            continue
        fi

        break
    done
    echo "$mfe_name"
}

# Function to prompt for MFE type
get_mfe_type() {
    while true; do
        print_question "Is this MFE a user journey or structural MFE?"
        echo "1) User Journey MFE"
        echo "2) Structural MFE"
        read -r -p "Enter your choice (1 or 2): " choice

        case $choice in
            1)
                echo "user-journey"
                break
                ;;
            2)
                echo "structural"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Function to replace seed-mfe-example with new project name
replace_project_references() {
    local old_name="seed-mfe-example"
    local new_name="$1"
    local project_dir="$2"

    print_status "Replacing '$old_name' references with '$new_name'..."

    # Find and replace in all relevant files
    find "$project_dir" -type f \( -name "*.json" -o -name "*.js" -o -name "*.ts" -o -name "*.html" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \) -exec grep -l "$old_name" {} \; | while read -r file; do
        print_status "Updating references in: $(basename "$file")"
        sed -i '' "s/$old_name/$new_name/g" "$file"
    done
}

# Function to create GitHub repository
create_github_repo() {
    local repo_name="$1"
    local mfe_type="$2"
    local description="Micro Frontend - $mfe_type MFE: $repo_name"

    print_status "Creating GitHub repository: $repo_name"

    if gh repo create "Ngx-Workshop/$repo_name" --public --description "$description" --clone=false; then
        print_status "Repository created successfully: https://github.com/Ngx-Workshop/$repo_name"
        echo "https://github.com/Ngx-Workshop/$repo_name.git"
    else
        print_error "Failed to create GitHub repository. Please check your permissions and try again."
        exit 1
    fi
}

# Main script execution
main() {
    print_status "Starting MFE Remote Creation Process"
    echo "======================================"

    # Check prerequisites
    check_gh_cli

    # Get user input
    mfe_name=$(get_mfe_name)
    mfe_type=$(get_mfe_type)

    # Construct project name based on type
    if [[ "$mfe_type" == "user-journey" ]]; then
        project_name="mfe-user-journey-$mfe_name"
    else
        project_name="mfe-structural-$mfe_name"
    fi

    print_status "Project name: $project_name"
    print_status "MFE type: $mfe_type"

    # Confirm with user
    print_question "Proceed with creating '$project_name'? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled by user."
        exit 0
    fi

    # Create GitHub repository first
    repo_url=$(create_github_repo "$project_name" "$mfe_type")

    # Navigate to NGX-WORKSHOP-ORG directory
    print_status "Navigating to ~/NGX-WORKSHOP-ORG"
    cd ~/NGX-WORKSHOP-ORG || {
        print_error "Cannot navigate to ~/NGX-WORKSHOP-ORG. Please ensure the directory exists."
        exit 1
    }

    # Clone the seed repository
    print_status "Cloning seed-mfe-remote template..."
    if git clone https://github.com/Ngx-Workshop/seed-mfe-remote.git "$project_name"; then
        print_status "Template cloned successfully"
    else
        print_error "Failed to clone template repository"
        exit 1
    fi

    # Navigate to project directory
    cd "$project_name" || {
        print_error "Cannot navigate to $project_name directory"
        exit 1
    }

    # Replace project references before git operations
    replace_project_references "$project_name" "$(pwd)"

    # Remove existing git history and initialize new repository
    print_status "Initializing new git repository..."
    rm -rf .git
    git init
    git remote add origin "$repo_url"
    git checkout -b main
    git add .
    git commit -m "Initial commit from seed-mfe-remote template for $project_name"

    # Push to remote repository
    print_status "Pushing to remote repository..."
    if git push -u origin main; then
        print_status "Code pushed successfully to remote repository"
    else
        print_error "Failed to push to remote repository"
        exit 1
    fi

    # Install dependencies
    print_status "Installing npm dependencies..."
    if npm install; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi

    # Run development bundle
    print_status "Running development bundle..."
    npm run dev:bundle

    print_status "MFE Remote creation completed successfully!"
    echo "======================================"
    print_status "Project: $project_name"
    print_status "Type: $mfe_type MFE"
    print_status "Repository: https://github.com/Ngx-Workshop/$project_name"
    print_status "Local path: ~/NGX-WORKSHOP-ORG/$project_name"
}

# Run the main function
main "$@"