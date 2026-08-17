import os

def export_flutter_to_txt(output_filename="flutter_project_code.txt"):
    # Folders we want to ignore (to keep the text file clean)
    ignore_dirs = {
        '.git', '.dart_tool', '.idea', 'build','dist','scripts','snap', 
        'ios', 'android', 'linux', 'macos', 'windows', 'web',
        'test', 'node_modules','scripts', 'assets', 'images', 'fonts','server_fastapi','sk_bags_repairing'
    }
    
    # Extensions we want to include
    include_extensions = {'.dart', '.yaml', '.gradle', '.xml'}

    # Files to ignore specifically
    ignore_files = {output_filename, 'pubspec.lock'}

    with open(output_filename, 'w', encoding='utf-8') as outfile:
        # Walk through the current directory
        for root, dirs, files in os.walk('.'):
            # Modify dirs in-place to skip ignored directories
            dirs[:] = [d for d in dirs if d not in ignore_dirs]

            for file in files:
                if file in ignore_files:
                    continue

                if any(file.endswith(ext) for ext in include_extensions):
                    file_path = os.path.join(root, file)
                    
                    # Normalize path for readability (removes leading ./)
                    display_path = os.path.relpath(file_path, '.')

                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as infile:
                            content = infile.read()
                            
                            # Write header for the file
                            outfile.write("=" * 80 + "\n")
                            outfile.write(f"FILE: {display_path}\n")
                            outfile.write("=" * 80 + "\n\n")
                            
                            # Write content
                            outfile.write(content)
                            outfile.write("\n\n")
                            
                        print(f"Added: {display_path}")
                    except Exception as e:
                        print(f"Could not read {display_path}: {e}")

    print(f"\nDone! All code has been saved to: {output_filename}")

if __name__ == "__main__":
    export_flutter_to_txt()