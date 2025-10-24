#!/bin/bash

# explode-assembly.sh
# Reverse of implode-assembly.sh - extracts edited content from an imploded file
# back to the original module and snippet files

set -euo pipefail

# Configuration
backup_suffix=".bak"
dry_run=false
verbose=false
create_backups=true
output_base_dir=""

# Parse command line arguments
declare -a args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      dry_run=true
      shift
      ;;
    -v|--verbose)
      verbose=true
      shift
      ;;
    --no-backup)
      create_backups=false
      shift
      ;;
    -o|--output-dir)
      output_base_dir="$2"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [OPTIONS] <imploded_file.txt>

Explodes an imploded assembly file back to its original module and snippet files.

OPTIONS:
  -n, --dry-run       Show what would be done without actually writing files
  -v, --verbose       Show detailed processing information
  --no-backup         Don't create .bak backup files before overwriting
  -o, --output-dir    Override output directory (default: extracts from metadata)
  -h, --help          Show this help message

EXAMPLES:
  $0 imploded_assembly.txt
  $0 -n -v imploded_assembly.txt       # Dry run with verbose output
  $0 --no-backup imploded_assembly.txt # Don't create backups
  $0 -o ~/openshift-docs imploded_assembly.txt # Override output directory

NOTES:
  - The script uses markers like "// BEGIN inlined:" and "// END inlined:" to identify content
  - Source file path is extracted from metadata at the top of the imploded file
  - Nested includes are handled recursively
  - By default, creates .bak backups of all modified files
EOF
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [[ "${#args[@]}" -ne 1 ]]; then
  echo "Error: Expected exactly one input file"
  echo "Use -h or --help for usage information"
  exit 1
fi

imploded_file="${args[0]}"

if [[ ! -f "$imploded_file" ]]; then
  echo "Error: File not found: $imploded_file"
  exit 1
fi

# Extract metadata from imploded file
extract_metadata() {
  local file="$1"
  local source_file=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^//[[:space:]]*Source[[:space:]]*file:[[:space:]]*(.+)$ ]]; then
      source_file="${BASH_REMATCH[1]}"
      source_file=$(echo "$source_file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      break
    fi
  done < "$file"

  echo "$source_file"
}

# Extract the directory where original assembly lives
get_base_directory() {
  local source_file="$1"

  if [[ -n "$output_base_dir" ]]; then
    echo "$output_base_dir"
    return
  fi

  # Extract directory from source file path
  local dir_path="${source_file%/*}"

  # Try to find the directory
  if [[ -d "$dir_path" ]]; then
    echo "$dir_path"
  else
    # Try to find openshift-docs directory as fallback
    if [[ -d "$HOME/openshift-docs" ]]; then
      echo "$HOME/openshift-docs"
    else
      echo "."
    fi
  fi
}

# Extract content for a specific file from imploded content
# This handles nested BEGIN/END markers correctly
extract_file_content() {
  local file_path="$1"
  local input_content="$2"
  local depth=0
  local capturing=false
  local result=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^//[[:space:]]*BEGIN[[:space:]]*inlined:[[:space:]]*(.+)$ ]]; then
      local marker_path="${BASH_REMATCH[1]}"
      marker_path=$(echo "$marker_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [[ "$marker_path" == "$file_path" ]]; then
        if [[ $depth -eq 0 ]]; then
          capturing=true
        fi
        ((depth++))
      elif [[ "$capturing" == true ]]; then
        # Nested BEGIN marker
        result+="$line"$'\n'
        ((depth++))
      fi
    elif [[ "$line" =~ ^//[[:space:]]*END[[:space:]]*inlined:[[:space:]]*(.+)$ ]]; then
      local marker_path="${BASH_REMATCH[1]}"
      marker_path=$(echo "$marker_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      if [[ "$capturing" == true ]]; then
        ((depth--))
        if [[ $depth -eq 0 ]]; then
          capturing=false
          break
        else
          # Nested END marker
          result+="$line"$'\n'
        fi
      fi
    elif [[ "$capturing" == true ]]; then
      result+="$line"$'\n'
    fi
  done <<< "$input_content"

  echo -n "$result"
}

# Find all unique module and snippet paths in the imploded file
find_all_included_files() {
  local file="$1"
  local files=()

  while IFS= read -r line; do
    if [[ "$line" =~ ^//[[:space:]]*BEGIN[[:space:]]*inlined:[[:space:]]*(.+)$ ]]; then
      local file_path="${BASH_REMATCH[1]}"
      file_path=$(echo "$file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      # Only capture top-level modules and snippets
      if [[ "$file_path" =~ ^(modules|snippets)/ ]]; then
        files+=("$file_path")
      fi
    fi
  done < "$file"

  # Remove duplicates while preserving order
  printf '%s\n' "${files[@]}" | awk '!seen[$0]++'
}

# Process the assembly file itself (extract content that's not in modules/snippets)
extract_assembly_content() {
  local input_content="$1"
  local result=""
  local in_metadata=true
  local skip_depth=0

  while IFS= read -r line; do
    # Skip initial comment block and metadata
    if [[ "$in_metadata" == true ]]; then
      if [[ "$line" =~ ^//[[:space:]]*Imploded[[:space:]]*on: ]] || \
         [[ "$line" =~ ^//[[:space:]]*Git[[:space:]]*branch: ]] || \
         [[ "$line" =~ ^//[[:space:]]*Source[[:space:]]*file: ]] || \
         [[ "$line" =~ ^//[[:space:]]*This[[:space:]]*file[[:space:]]*contains ]] || \
         [[ "$line" =~ ^//[[:space:]]*It[[:space:]]*is[[:space:]]*not ]] || \
         [[ "$line" =~ ^//[[:space:]]*and[[:space:]]*the[[:space:]]*full ]] || \
         [[ "$line" =~ ^//[[:space:]]*Includes[[:space:]]*that ]] || \
         [[ "$line" =~ ^//[[:space:]]*The[[:space:]]*purpose ]] || \
         [[ "$line" =~ ^//[[:space:]]*so[[:space:]]*that ]] || \
         [[ "$line" =~ ^//[[:space:]]*without[[:space:]]*needing ]] || \
         [[ -z "$line" ]]; then
        continue
      else
        in_metadata=false
      fi
    fi

    # Track BEGIN/END markers to skip inlined content
    if [[ "$line" =~ ^//[[:space:]]*BEGIN[[:space:]]*inlined:[[:space:]]*(modules|snippets)/ ]]; then
      ((skip_depth++))
    elif [[ "$line" =~ ^//[[:space:]]*END[[:space:]]*inlined:[[:space:]]*(modules|snippets)/ ]]; then
      ((skip_depth--))
    elif [[ $skip_depth -eq 0 ]]; then
      # Only add lines that aren't inside a module/snippet block
      result+="$line"$'\n'
    fi
  done <<< "$input_content"

  echo -n "$result"
}

# Main processing
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Exploding assembly: $imploded_file"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Extract metadata
source_file=$(extract_metadata "$imploded_file")
if [[ -z "$source_file" ]]; then
  echo "Error: Could not find source file metadata in imploded file"
  exit 1
fi

echo "Source assembly: $source_file"

# Determine base directory
base_dir=$(get_base_directory "$source_file")
echo "Base directory:  $base_dir"

if [[ "$dry_run" == true ]]; then
  echo "DRY RUN MODE - No files will be modified"
fi

if [[ "$create_backups" == false ]]; then
  echo "Backups disabled"
fi

echo ""

# Read entire imploded file
imploded_content=$(<"$imploded_file")

# Find all modules and snippets
echo "Finding included files..."
included_files=$(find_all_included_files "$imploded_file")

if [[ -z "$included_files" ]]; then
  echo "Warning: No modules or snippets found in imploded file"
else
  echo "Found $(echo "$included_files" | wc -l) included file(s)"
  echo ""
fi

# Extract and write each module/snippet
file_count=0
while IFS= read -r file_path; do
  [[ -z "$file_path" ]] && continue

  ((file_count++))

  output_path="$base_dir/$file_path"
  output_dir=$(dirname "$output_path")

  if [[ "$verbose" == true ]]; then
    echo "Processing: $file_path"
  fi

  # Extract content for this file
  content=$(extract_file_content "$file_path" "$imploded_content")

  if [[ -z "$content" ]]; then
    echo "Warning: No content extracted for $file_path"
    continue
  fi

  # Create directory if it doesn't exist
  if [[ "$dry_run" == false ]]; then
    mkdir -p "$output_dir"
  fi

  # Create backup if file exists and backups are enabled
  if [[ -f "$output_path" ]] && [[ "$create_backups" == true ]] && [[ "$dry_run" == false ]]; then
    cp "$output_path" "${output_path}${backup_suffix}"
    if [[ "$verbose" == true ]]; then
      echo "  Created backup: ${output_path}${backup_suffix}"
    fi
  fi

  # Write the file
  if [[ "$dry_run" == false ]]; then
    echo -n "$content" > "$output_path"
    echo "  ✓ Written: $output_path"
  else
    echo "  [DRY RUN] Would write: $output_path"
  fi

  if [[ "$verbose" == true ]]; then
    echo "  Content size: $(echo -n "$content" | wc -c) bytes, $(echo "$content" | wc -l) lines"
    echo ""
  fi
done <<< "$included_files"

# Extract and write assembly file
echo ""
echo "Processing assembly file..."
assembly_content=$(extract_assembly_content "$imploded_content")
assembly_path="$base_dir/$source_file"
assembly_dir=$(dirname "$assembly_path")

if [[ "$dry_run" == false ]]; then
  mkdir -p "$assembly_dir"
fi

if [[ -f "$assembly_path" ]] && [[ "$create_backups" == true ]] && [[ "$dry_run" == false ]]; then
  cp "$assembly_path" "${assembly_path}${backup_suffix}"
  if [[ "$verbose" == true ]]; then
    echo "  Created backup: ${assembly_path}${backup_suffix}"
  fi
fi

if [[ "$dry_run" == false ]]; then
  echo -n "$assembly_content" > "$assembly_path"
  echo "  ✓ Written: $assembly_path"
else
  echo "  [DRY RUN] Would write: $assembly_path"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Explosion complete!"
echo "Files processed: $file_count modules/snippets + 1 assembly"
if [[ "$dry_run" == false ]] && [[ "$create_backups" == true ]]; then
  echo "Backups created with suffix: $backup_suffix"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
