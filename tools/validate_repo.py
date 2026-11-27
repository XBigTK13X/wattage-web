import os
import re
import sys

FORBIDDEN_PATHS = [
    "airef/physical",
    "airef/dredmor/asset",
]

SINGLE_CHAR_VAR_PATTERN = re.compile(r"\bvar\s+([A-Za-z_])\b")
SINGLE_CHAR_FOR_PATTERN = re.compile(r"\bfor\s+([A-Za-z_])\s+in\b")


def collect_project_files(root_dir):
    collected = []
    for folder_name in ["scene", "script", "data", "asset"]:
        folder_path = os.path.join(root_dir, folder_name)
        if not os.path.isdir(folder_path):
            continue
        for current_root, _dirs, files in os.walk(folder_path):
            for file_name in files:
                if file_name.endswith((".gd", ".tscn", ".tres", ".json")):
                    collected.append(os.path.join(current_root, file_name))
    project_file = os.path.join(root_dir, "project.godot")
    if os.path.isfile(project_file):
        collected.append(project_file)
    return sorted(collected)


def validate_file(file_path, root_dir):
    errors = []
    relative_path = os.path.relpath(file_path, root_dir)
    with open(file_path, "r", encoding="utf-8") as handle:
        lines = handle.readlines()
    for line_number, line_text in enumerate(lines, start=1):
        for forbidden in FORBIDDEN_PATHS:
            if forbidden in line_text:
                errors.append(f"{relative_path}:{line_number}: forbidden reference '{forbidden}'")
        if file_path.endswith(".gd"):
            var_match = SINGLE_CHAR_VAR_PATTERN.search(line_text)
            if var_match:
                errors.append(f"{relative_path}:{line_number}: single-character variable '{var_match.group(1)}'")
            for_match = SINGLE_CHAR_FOR_PATTERN.search(line_text)
            if for_match:
                errors.append(f"{relative_path}:{line_number}: single-character loop index '{for_match.group(1)}'")
    return errors


def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    project_files = collect_project_files(root_dir)
    total_files = len(project_files)
    all_errors = []
    for index, file_path in enumerate(project_files, start=1):
        print(f"Checking {index}/{total_files}: {os.path.relpath(file_path, root_dir)}")
        all_errors.extend(validate_file(file_path, root_dir))
    if all_errors:
        for error in all_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Validation passed across {total_files} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
