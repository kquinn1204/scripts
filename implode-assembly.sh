#!/bin/bash

output_root="$HOME/imploded_assemblies"
mkdir -p "$output_root"

suppress_output=false
file_list=""
combined_output=""

declare -a args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quiet)
      suppress_output=true
      shift
      ;;
    -f|--file-list)
      file_list="$2"
      shift 2
      ;;
    -c|--combined)
      combined_output="$2"
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

ai_comment_block='// This file contains a fully expanded version of an OpenShift documentation *assembly* written in AsciiDoc.
// It is not valid AsciiDoc for publishing, because it includes both the original `include::` statements
// and the full contents of the referenced *module* or *snippet* files placed immediately underneath each include.
// Includes that reference `_attributes/` files remain untouched, as attribute files are not inlined.
// The purpose of this imploded version is to expose the raw AsciiDoc used throughout the document
// so that AI tools can analyze document structure, content organization, and AsciiDoc conventions
// without needing to resolve external files.'

inline_file_recursively() {
  local file_path="$1"
  local file_dir="$(dirname "$file_path")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if echo "$line" | grep -q 'include::.*\.adoc'; then
      include_target="$(echo "$line" | sed -nE 's/.*include::([^\[]+\.adoc).*/\1/p')"
      resolved_path="$file_dir/$include_target"

      if [[ "$include_target" == */_attributes/* ]]; then
        echo "$line"
      elif [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $include_target"
        inline_file_recursively "$resolved_path"
        echo "// END inlined: $include_target"
      else
        echo "// WARNING: could not resolve $include_target"
      fi
    else
      echo "$line"
    fi
  done < "$file_path"
}

implode_file() {
  local input_file="$1"
  local label="$2"

  local -a included_modules=()
  local -a included_snippets=()

  local temp_content temp_final
  temp_content=$(mktemp)
  temp_final=$(mktemp)

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local input_dir="$(dirname "$input_file")"
  local git_branch
  git_branch="$(git -C "$input_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  git_branch="${git_branch:-not-in-git}"

  local base_name="$(basename "$input_file" .adoc)"
  local input_base="$(basename "$label")"
  local rel_path="${label%/*}"
  local output_subdir="$output_root/$rel_path"
  mkdir -p "$output_subdir"

  local output_file=""
  local counter=1

  # If combined mode is enabled, skip individual file creation
  if [[ -z "$combined_output" ]]; then
    while true; do
      output_file="$output_subdir/${base_name}_${git_branch}_v${counter}.txt"
      [[ ! -e "$output_file" ]] && break
      ((counter++))
    done
  fi

  echo "// Imploded on: $timestamp" >> "$temp_content"
  echo "// Git branch:  $git_branch" >> "$temp_content"
  echo "// Source file: $label" >> "$temp_content"
  echo "" >> "$temp_content"

  while IFS= read -r line || [[ -n "$line" ]]; do
    echo "$line" >> "$temp_content"

    if echo "$line" | grep -q 'include::modules/.*\.adoc'; then
      module_path="$(echo "$line" | sed -nE 's/.*include::(modules\/[^\[]+\.adoc).*/\1/p')"
      [[ -n "$module_path" ]] && included_modules+=("$module_path")
      resolved_path="$input_dir/$module_path"

      if [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $module_path" >> "$temp_content"
        inline_file_recursively "$resolved_path" >> "$temp_content"
        echo "// END inlined: $module_path" >> "$temp_content"
      else
        echo "// WARNING: missing module $module_path" >> "$temp_content"
      fi

    elif echo "$line" | grep -q 'include::snippets/.*\.adoc'; then
      snippet_path="$(echo "$line" | sed -nE 's/.*include::(snippets\/[^\[]+\.adoc).*/\1/p')"
      [[ -n "$snippet_path" ]] && included_snippets+=("$snippet_path")
      resolved_path="$input_dir/$snippet_path"

      if [[ -f "$resolved_path" ]]; then
        echo "// BEGIN inlined: $snippet_path" >> "$temp_content"
        inline_file_recursively "$resolved_path" >> "$temp_content"
        echo "// END inlined: $snippet_path" >> "$temp_content"
      else
        echo "// WARNING: missing snippet $snippet_path" >> "$temp_content"
      fi
    fi
  done < "$input_file"

  echo "$ai_comment_block" > "$temp_final"
  echo "" >> "$temp_final"
  cat "$temp_content" >> "$temp_final"

  # If combined mode, append to combined file instead of creating individual file
  if [[ -n "$combined_output" ]]; then
    echo "" >> "$combined_output"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$combined_output"
    echo "// Assembly: $label" >> "$combined_output"
    echo "// Imploded on: $timestamp" >> "$combined_output"
    echo "// Git branch: $git_branch" >> "$combined_output"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$combined_output"
    echo "" >> "$combined_output"
    cat "$temp_final" >> "$combined_output"
    rm "$temp_content" "$temp_final"

    if [[ "$suppress_output" == false ]]; then
      echo "Appended: $label"
    fi
  else
    mv "$temp_final" "$output_file"
    rm "$temp_content"

    if [[ "$suppress_output" == false ]]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " Output file:    $output_file"
      echo " Source:         $label"
      echo " Timestamp:      $timestamp"
      echo " Git branch:     $git_branch"
      echo " Modules:        ${#included_modules[@]}"
      for m in "${included_modules[@]}"; do echo "   • $m"; done
      echo " Snippets:       ${#included_snippets[@]}"
      for s in "${included_snippets[@]}"; do echo "   • $s"; done
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    else
      if [[ "$quiet_header_shown" != true ]]; then
        echo "Generated files:"
        quiet_header_shown=true
      fi
      echo "$output_file"
    fi
  fi
}

# MAIN
if [[ "${#args[@]}" -eq 0 && -z "$file_list" ]]; then
  echo "Usage: $0 [--quiet|-q] [--file-list|-f <file.txt>] [--combined|-c <output.txt>] <assembly.adoc> [more_files_or_dirs...]"
  echo ""
  echo "Options:"
  echo "  -q, --quiet          Suppress detailed output, show only file paths"
  echo "  -f, --file-list      Read .adoc file paths from a text file (one per line)"
  echo "  -c, --combined       Combine all outputs into a single file instead of individual files"
  echo ""
  echo "Examples:"
  echo "  $0 assembly.adoc"
  echo "  $0 -f filelist.txt"
  echo "  $0 -q -f filelist.txt"
  echo "  $0 -c combined.txt -f filelist.txt"
  echo "  $0 --combined all_assemblies.txt file1.adoc file2.adoc directory/"
  exit 1
fi

# If combined mode is enabled, initialize the combined file
if [[ -n "$combined_output" ]]; then
  # Create the combined output file with header
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "// Combined Imploded Assemblies" > "$combined_output"
  echo "// Generated on: $timestamp" >> "$combined_output"
  echo "// This file contains multiple imploded OpenShift documentation assemblies" >> "$combined_output"
  echo "" >> "$combined_output"
  echo "$ai_comment_block" >> "$combined_output"

  if [[ "$suppress_output" == false ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Combined mode enabled"
    echo " Output file: $combined_output"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
fi

# Process files from file list if provided
if [[ -n "$file_list" ]]; then
  if [[ ! -f "$file_list" ]]; then
    echo "Error: File list '$file_list' not found"
    exit 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Trim whitespace
    file=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$file" ]] && continue

    if [[ -f "$file" && "$file" == *.adoc ]]; then
      abs_path="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
      implode_file "$abs_path" "$file"
    else
      echo "Warning: Skipping invalid or non-existent file from list: $file"
    fi
  done < "$file_list"
fi

# Process files from command-line arguments
for arg in "${args[@]}"; do
  if [[ -f "$arg" && "$arg" == *.adoc ]]; then
    abs_path="$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"
    implode_file "$abs_path" "$arg"
  elif [[ -d "$arg" ]]; then
    find "$arg" -type f -name '*.adoc' | while IFS= read -r file; do
      abs_path="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
      implode_file "$abs_path" "$file"
    done
  else
    echo "Skipping unrecognized argument: $arg"
  fi

done

# If combined mode is enabled, print final summary
if [[ -n "$combined_output" ]]; then
  if [[ "$suppress_output" == false ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Combined file created successfully"
    echo " Output file: $combined_output"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
fi
