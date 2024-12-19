import os
import re
import shutil

# Paths
posts_dir = "/mnt/c/Users/tknza/iCloudDrive/iCloud~md~obsidian/blog-posts"
attachments_dir = "/mnt/c/Users/tknza/iCloudDrive/iCloud~md~obsidian/_assets"
static_images_dir = "/home/dakim/workspace/k3s/apps/jekyll-blog/assets"

# Step 1: Process each markdown file in the posts directory
for filename in os.listdir(posts_dir):
    if filename.endswith(".md"):
        filepath = os.path.join(posts_dir, filename)
        
        with open(filepath, "r") as file:
            content = file.read()
        
        # Step 2: Find all image links in the format ![Image Description](/images/Pasted%20image%20...%20.png)
        images = re.findall(r'!\[.*?\]\((.*?\.(?:png|jpg|jpeg|svg))\)', content)
        
        for image in images:
            # Step 3: Copy the image to the Jekyll static/images directory if it exists
            image_source = os.path.join(attachments_dir, image.split('/')[-1])
            if os.path.exists(image_source):
                shutil.copy(image_source, static_images_dir)

print("Markdown files processed and images copied successfully.")

