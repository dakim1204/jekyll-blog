#!/bin/bash
set -euo pipefail

# Change to the app root directory
APP_DIR="/home/dakim/workspace/k3s/apps/jekyll-blog"
cd $APP_DIR

# Set variables for Obsidian to Jekyll copy
sourcePath="/mnt/c/Users/tknza/iCloudDrive/iCloud~md~obsidian/blog-posts/"
destinationPath="/home/dakim/workspace/k3s/apps/jekyll-blog/_posts/"

git_status=$(git status --porcelain)
current_datetime=$(date "+%Y-%m-%d %H:%M:%S")
new_posts=$(echo "$git_status" | grep -E "(_posts/|assets/)")
site_config=$(echo "$git_status" | grep -vE "(_posts/|assets/)")

# Set GitHub Repo
repo="jekyll-blog"

# Check for required commands
for cmd in git rsync python3; do
  if ! command -v $cmd &>/dev/null; then
    echo "$cmd is not installed or not in PATH."
    exit 1
  fi
done

# Step 1: Check if Git is initialized, and initialize if necessary
if [ ! -d ".git" ]; then
  echo "Initializing Git repository..."
  git init
  git remote add origin $repo
else
  echo "Git repository already initialized."
  if ! git remote | grep -q 'origin'; then
    echo "Adding remote origin..."
    git remote add origin $repo
  fi
fi

# Step 2: Sync posts from Obsidian to Hugo content folder using rsync
echo "Syncing posts from Obsidian..."

if [ ! -d "$sourcePath" ]; then
  echo "Source path does not exist: $sourcePath"
  exit 1
fi

if [ ! -d "$destinationPath" ]; then
  echo "Destination path does not exist: $destinationPath"
  exit 1
fi

rsync -av --delete --no-perms --no-owner --no-group -0 "$sourcePath" "$destinationPath"

# Step 3: Process Markdown files with Python script to handle image links
echo "Processing image links in Markdown files..."
if [ ! -f "tools/copy-images.py" ]; then
  echo "Python script copy-images.py not found."
  exit 1
fi

if ! python3 tools/copy-images.py; then
  echo "Failed to process image links."
  exit 1
fi

# Step 4: Check if there is a change in repository
if [ -n "$new_posts" ]; then
  git add _posts/ assets/
  git commit -m "new blog post on $current_datetime"
fi

if [ -n "$site_config" ]; then
  git add .
  git commit -m "site configuration"
fi

# Step 5: Push all changes to the main branch
echo "Deploying to GitHub Main..."
if ! git push origin main; then
  echo "Failed to push to main branch."
  exit 1
fi

# Step 6: Build docker image and push to registry
echo "Building docker image..."
if ! docker build --no-cache -t registry.dakim.dev/blog/jekyll/chirpy:latest .; then
  echo "Docker build failed."
  exit 1
fi

if ! docker push registry.dakim.dev/blog/jekyll/chirpy:latest; then
  echo "Docker push failed."
  exit 1
fi

# Step 7: Restart jekyll-blog deployments
echo "Restarting jekyll-blog deployments..."
if ! kubectl -n apps rollout restart deployments/jekyll-blog; then
  echo "Failed to restart deployments/jekyll-blog"
  exit 1
fi

echo "All done! Site synced, processed, committed, built, and deployed."
