import os

def clean_macos_files():
    # Files to look for
    # .DS_Store: Folder settings
    # ._* : AppleDouble files (metadata for files)
    
    deleted_count = 0
    total_size = 0

    print(f"Scanning directory: {os.getcwd()}")
    print("Searching for macOS junk files...")

    for root, dirs, files in os.walk("."):
        for file in files:
            # Check for .DS_Store or files starting with ._
            if file == ".DS_Store" or file.startswith("._") or file.startswith("._."):
                file_path = os.path.join(root, file)
                
                try:
                    # Get size for reporting
                    total_size += os.path.getsize(file_path)
                    
                    # Delete the file
                    os.remove(file_path)
                    print(f"Deleted: {file_path}")
                    deleted_count += 1
                except Exception as e:
                    print(f"Error deleting {file_path}: {e}")

    print("-" * 30)
    print(f"Cleanup Complete!")
    print(f"Total files removed: {deleted_count}")
    print(f"Space recovered: {total_size / 1024:.2f} KB")

if __name__ == "__main__":
    confirm = input("This will delete all .DS_Store and ._ files in this and all sub-folders. Proceed? (y/n): ")
    if confirm.lower() == 'y':
        clean_macos_files()
    else:
        print("Cancelled.")