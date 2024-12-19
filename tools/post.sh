#!/bin/bash
set -euo pipefail

# Change to the app root directory
APP_DIR="/home/dakim/workspace/k3s/apps/jekyll-blog"
TOOL_DIR="$APP_DIR/tools"
cd $APP_DIR

# Set variables for Obsidian to Jekyll copy
sourcePath="/mnt/c/Users/tknza/iCloudDrive/iCloud~md~obsidian/blog-posts/"
destinationPath="/home/dakim/workspace/k3s/apps/jekyll-blog/_posts/"

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
cd $TOOL_DIR
if [ ! -f "copy-images.py" ]; then
  echo "Python script copy-images.py not found."
  exit 1
fi

if ! python3 copy-images.py; then
  echo "Failed to process image links."
  exit 1
fi

# Step 4: Build docker image and push to registry
echo "Building docker image..."
cd $APP_DIR
if ! docker build --no-cache -t registry.dakim.dev/blog/jekyll/chirpy:latest .; then
  echo "Docker build failed."
  exit 1
fi

if ! docker push registry.dakim.dev/blog/jekyll/chirpy:latest; then
  echo "Docker push failed."
  exit 1
fi

# Step 5: Add changes to Git
echo "Staging changes for Git..."
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to stage."
else
  git add .
fi

# Step 6: Commit changes with a dynamic message
commit_message="New Blog Post on $(date +'%Y-%m-%d %H:%M:%S')"
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  echo "Committing changes..."
  git commit -m "$commit_message"
fi

# Step 7: Push all changes to the main branch
echo "Deploying to GitHub Main..."
if ! git push origin main; then
  echo "Failed to push to main branch."
  exit 1
fi

# Step 8: Restart jekyll-blog deployments
echo "Restarting jekyll-blog deployments..."
if ! kubectl -n apps rollout restart deployments/jekyll-blog; then
  echo "Failed to restart deployments/jekyll-blog"
  exit 1
fi

echo "All done! Site synced, processed, committed, built, and deployed."
