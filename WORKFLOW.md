# Assembly Implode/Explode Workflow

This document describes the workflow for using `implode-assembly.sh` and `explode-assembly.sh` to prepare OpenShift AsciiDoc assemblies for DITA conversion validation and correction.

## Overview

The workflow enables you to:
1. **Implode** an assembly file - combine all included modules/snippets into a single file
2. **Validate** the combined file with DITA-vale or other validation tools
3. **Edit** the combined file to fix issues
4. **Explode** the edited file - extract changes back to original module/snippet files

## End Goal: DITA-Ready Files for GitHub

**What you start with:**
- Original individual `.adoc` files (assembly, modules, snippets) that may have DITA conversion issues

**What you end with:**
- The same individual `.adoc` files, now updated with DITA-compatible fixes
- Files ready to commit to GitHub
- Content that converts cleanly to DITA XML

**What you commit to GitHub:**
- ✅ Updated `assemblies/*.adoc` files
- ✅ Updated `modules/*.adoc` files
- ✅ Updated `snippets/*.adoc` files
- ❌ NOT the large combined text file (it's a temporary working file only)

**The large combined file is temporary** - it's your workspace for validation and editing. After exploding, you're back to the normal OpenShift documentation structure with individual DITA-ready files!

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1-2: IMPLODE ASSEMBLY                                         │
│                                                                     │
│  Individual Files              →           Combined File           │
│  ─────────────────                         ─────────────           │
│  assemblies/my.adoc                        my_v1.txt               │
│  modules/mod1.adoc          IMPLODE        (ALL content)           │
│  modules/mod2.adoc            ═══>         (with markers)          │
│  snippets/snip1.adoc                       (for validation)        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3: VALIDATE & EDIT                                            │
│                                                                     │
│  Combined File                 →           Edited Combined File    │
│  ─────────────                             ───────────────────     │
│  my_v1.txt                                 my_v1.txt               │
│  (DITA validation issues)      EDIT        (DITA-compatible)       │
│                                 ═══>       (all fixes applied)     │
│  Run: dita-vale my_v1.txt                                          │
│  Fix: code/vi my_v1.txt                                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 4-5: EXPLODE BACK TO INDIVIDUAL FILES                         │
│                                                                     │
│  Edited Combined               →           Updated Individual Files│
│  ─────────────────                         ─────────────────────── │
│  my_v1.txt                                 assemblies/my.adoc       │
│  (with all fixes)             EXPLODE      modules/mod1.adoc        │
│                                 ═══>       modules/mod2.adoc        │
│                                            snippets/snip1.adoc      │
│                                            (ALL DITA-READY!)        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 6-8: VERIFY, BUILD, COMMIT TO GITHUB                          │
│                                                                     │
│  git status                    →           GitHub Repository       │
│  git diff                                  ──────────────────       │
│  asciibinder build             COMMIT      assemblies/my.adoc       │
│  git add .                       ═══>      modules/mod1.adoc        │
│  git commit                                modules/mod2.adoc        │
│  git push                                  snippets/snip1.adoc      │
│                                                                     │
│                                            ✅ DITA-READY FOR        │
│                                               CONVERSION!           │
└─────────────────────────────────────────────────────────────────────┘

KEY POINT: The combined text file (my_v1.txt) is TEMPORARY workspace only.
           Your deliverable is the updated individual .adoc files on GitHub.
```

## Scripts

### implode-assembly.sh

**Purpose:** Combines an assembly file and all its included modules/snippets into a single text file for analysis.

**Key Features:**
- Recursively inlines all `include::modules/` and `include::snippets/` references
- Preserves original `include::` statements for reference
- Adds `// BEGIN inlined:` and `// END inlined:` markers around inlined content
- Handles nested includes
- Preserves `include::_attributes/` statements (not inlined)
- Adds metadata (timestamp, git branch, source file path)
- Supports combined output mode (multiple assemblies in one file)

**Usage:**
```bash
# Single assembly file
./implode-assembly.sh assembly.adoc

# Multiple files from a list
./implode-assembly.sh -f file_list.txt

# Combined mode (all assemblies in one file)
./implode-assembly.sh -c combined_output.txt -f file_list.txt

# Quiet mode
./implode-assembly.sh -q assembly.adoc
```

**Output Location:** `~/imploded_assemblies/`

**Output Format:**
```
// Imploded on: 2025-10-24 14:30:00
// Git branch:  my-feature-branch
// Source file: assemblies/my-assembly.adoc

[assembly content]
include::modules/my-module.adoc[]
// BEGIN inlined: modules/my-module.adoc
[module content]
// END inlined: modules/my-module.adoc
```

### explode-assembly.sh

**Purpose:** Reverses the implode process by extracting edited content from an imploded file back to original source files.

**Key Features:**
- Parses `// BEGIN inlined:` and `// END inlined:` markers
- Extracts content for each module/snippet
- Handles nested includes correctly
- Creates backups by default (`.bak` suffix)
- Dry-run mode to preview changes
- Verbose mode for detailed output
- Reconstructs assembly file (without inlined content)
- Preserves final newlines (POSIX text file requirement)

**Usage:**
```bash
# Basic usage for openshift-docs (REQUIRED: use -o flag)
./explode-assembly.sh -o ~/openshift-docs imploded_file.txt

# Dry run (see what would happen)
./explode-assembly.sh -n -o ~/openshift-docs imploded_file.txt

# Verbose output
./explode-assembly.sh -v -o ~/openshift-docs imploded_file.txt

# No backups
./explode-assembly.sh --no-backup -o ~/openshift-docs imploded_file.txt

# Dry run + verbose
./explode-assembly.sh -n -v -o ~/openshift-docs imploded_file.txt
```

**Important for openshift-docs:** The `-o ~/openshift-docs` flag is REQUIRED because modules and snippets directories are at the repository root, not in the assembly's subdirectory. Without this flag, the script cannot locate the correct output paths.

## Complete Workflow

### Step 1: Implode the Assembly

First, identify the assembly file you want to work with and create an imploded version:

```bash
cd ~/openshift-docs
./path/to/implode-assembly.sh assemblies/my-assembly.adoc
```

This creates: `~/imploded_assemblies/assemblies/my-assembly_<branch>_v1.txt`

### Step 2: Validate with DITA Tools

Run your DITA validation tool (e.g., dita-vale) on the imploded file:

```bash
dita-vale ~/imploded_assemblies/assemblies/my-assembly_main_v1.txt > validation_report.txt
```

### Step 3: Fix Issues in the Imploded File

Edit the imploded file to fix any DITA conversion issues:

```bash
code ~/imploded_assemblies/assemblies/my-assembly_main_v1.txt
# or
vi ~/imploded_assemblies/assemblies/my-assembly_main_v1.txt
```

**Important editing guidelines:**
- Only edit content BETWEEN the `// BEGIN inlined:` and `// END inlined:` markers
- DO NOT modify the markers themselves
- DO NOT modify the metadata at the top of the file
- DO NOT modify the `include::` statements (they're for reference only)
- Fix AsciiDoc syntax issues as identified by validation

### Step 4: Dry-Run the Explode

Before actually writing files, preview what will happen:

```bash
./path/to/explode-assembly.sh -n -v -o ~/openshift-docs ~/imploded_assemblies/assemblies/my-assembly_main_v1.txt
```

Review the output to ensure:
- Correct files will be updated
- Paths are resolved correctly
- Expected number of modules/snippets found

**Note:** The `-o ~/openshift-docs` flag is required for the openshift-docs repository structure.

### Step 5: Explode Back to Source Files

Extract the edited content back to the original files:

```bash
./path/to/explode-assembly.sh -o ~/openshift-docs ~/imploded_assemblies/assemblies/my-assembly_main_v1.txt
```

This will:
- Create `.bak` backups of all modified files
- Write updated content to original module/snippet files
- Update the assembly file (if edited)
- Print summary of files processed

**Important:** Always use the `-o ~/openshift-docs` flag to ensure files are written to the correct locations in the repository.

### Step 6: Verify Changes

Check the changes in your git repository:

```bash
cd ~/openshift-docs
git status
git diff
```

Review each changed file to ensure edits were applied correctly.

### Step 7: Test the Documentation Build

Build the documentation to ensure no syntax errors:

```bash
cd ~/openshift-docs
asciibinder build
```

### Step 8: Commit DITA-Ready Files to GitHub

**This is your end goal!** At this point, your individual `.adoc` files contain all the DITA-compatible fixes.

If everything looks good, commit your changes:

```bash
cd ~/openshift-docs

# Stage all the corrected individual .adoc files
git add assemblies/my-assembly.adoc
git add modules/*.adoc  # All updated modules
git add snippets/*.adoc # All updated snippets

# Commit the DITA-ready files
git commit -m "Fix DITA conversion issues in my-assembly

- Corrected AsciiDoc elements for DITA XML compatibility
- Validated with DITA-vale
- Ready for DITA conversion"

# Push to your GitHub fork
git push origin my-branch
```

**What you've accomplished:**
- ✅ Your individual `.adoc` files are now DITA-compatible
- ✅ Files are committed to version control
- ✅ Content is ready for clean DITA XML conversion
- ✅ The imploded text file served its purpose and can be deleted or archived

**Note:** The large combined text file (`~/imploded_assemblies/...`) was only a temporary workspace. You don't need to commit it or keep it after Step 8. Your actual work product is the updated individual `.adoc` files in your git repository.

## Working with Multiple Assemblies

### Create a File List

Create a text file with paths to multiple assemblies:

```bash
cat > assembly_list.txt <<EOF
assemblies/assembly1.adoc
assemblies/assembly2.adoc
assemblies/assembly3.adoc
EOF
```

### Implode Multiple Files

```bash
# Individual files
./implode-assembly.sh -f assembly_list.txt

# Combined into one file
./implode-assembly.sh -c combined_assemblies.txt -f assembly_list.txt
```

### Explode Multiple Files

If you used combined mode, you'll need to manually split the combined file back into individual files before exploding, OR edit in place and explode each section separately.

**Recommended approach:** Use individual imploded files for easier management.

## Tips and Best Practices

### Before Imploding
- Ensure you're on the correct git branch
- Pull latest changes from upstream
- Commit any local changes

### During Editing
- Use a proper text editor with AsciiDoc syntax highlighting
- Keep the structure of markers intact
- Don't remove BEGIN/END markers
- Test changes incrementally if possible

### After Exploding
- Always review `git diff` before committing
- Check backup files (`.bak`) if something goes wrong
- Run `asciibinder build` to verify syntax
- Test documentation renders correctly
- Note: Final newlines are automatically preserved - all files will end with `\n` per POSIX standards

### Recovery from Mistakes
If explode produces unexpected results:

```bash
# Restore from backups
cd ~/openshift-docs
find . -name "*.bak" -exec bash -c 'mv "$1" "${1%.bak}"' _ {} \;

# Or restore specific file
mv modules/my-module.adoc.bak modules/my-module.adoc

# Or use git to reset
git checkout modules/my-module.adoc
```

## Common Issues and Solutions

### Issue: "Could not find source file metadata"
**Cause:** The imploded file is missing the `// Source file:` metadata line.

**Solution:** Ensure you're using a file created by `implode-assembly.sh`. Check the first few lines for metadata.

### Issue: "No content extracted for <file>"
**Cause:** The BEGIN/END markers were modified or removed during editing.

**Solution:** Check that markers are intact:
```
// BEGIN inlined: modules/my-module.adoc
[content here]
// END inlined: modules/my-module.adoc
```

### Issue: Nested includes not handled correctly
**Cause:** Complex nesting structure.

**Solution:** Use verbose mode (`-v`) to see what's being extracted. The script tracks depth correctly, so this is usually a marker formatting issue.

### Issue: Wrong base directory / Files not found
**Cause:** The explode script cannot locate modules/snippets directories. This is the expected behavior for openshift-docs repository where these directories are at the root.

**Solution:** ALWAYS use `-o` flag to specify the repository root:
```bash
./explode-assembly.sh -o ~/openshift-docs imploded_file.txt
```

This is REQUIRED for openshift-docs, not optional. The repository structure has modules/ and snippets/ at the root level, while assemblies are in subdirectories like `scalability_and_performance/`.

### Issue: Files show changes but no visible diff / Missing final newlines
**Cause:** Files are missing their final newline character, which is required by POSIX text file standards.

**Background:** The explode script now automatically ensures all files end with a newline. In earlier versions, files would lose their final newline during the explode process due to bash command substitution behavior.

**What this means:**
- All text files should end with a newline character (`\n`)
- Git may show files as changed even when content appears identical
- Editors may warn "No newline at end of file"

**Solution:** The current version of the explode script automatically handles this:
1. Uses a sentinel technique (`$(cat file; echo x)` + `${var%x}`) to preserve newlines when reading the imploded file
2. Automatically adds a final newline to any file that doesn't have one

**If you're using an older version of the script:** Update to the latest version from the repository, which includes the final newline preservation fix.

## File Structure Reference

### Imploded File Structure
```
// [AI comment block - multi-line explanation]

// Imploded on: 2025-10-24 14:30:00
// Git branch:  my-branch
// Source file: assemblies/my-assembly.adoc

[assembly content with includes preserved]

include::modules/module1.adoc[]
// BEGIN inlined: modules/module1.adoc
[module1 content]
  include::snippets/snippet1.adoc[]
  // BEGIN inlined: snippets/snippet1.adoc
  [snippet content]
  // END inlined: snippets/snippet1.adoc
// END inlined: modules/module1.adoc
```

### Directory Structure

**Imploded Files Location:**
```
~/imploded_assemblies/
  <directory-structure-mirroring-source>/
    my-assembly_main_v1.txt
    my-assembly_main_v2.txt
```

**OpenShift-Docs Repository Structure:**
```
~/openshift-docs/                    ← Use this path with -o flag
  modules/                           ← At repository root
    module1.adoc
    module2.adoc
    cnf-about-*.adoc
    [thousands of module files]
  snippets/                          ← At repository root
    snippet1.adoc
  scalability_and_performance/       ← Assemblies in subdirectories
    cnf-tuning-low-latency-nodes-with-perf-profile.adoc
  networking/
    assembly-file.adoc
  [other topic directories with assemblies]
```

**Why `-o ~/openshift-docs` is Required:**

The openshift-docs repository has a flat structure where ALL modules and snippets are in top-level directories (`modules/` and `snippets/`), while assemblies are organized in topic-specific subdirectories. When exploding an assembly from `scalability_and_performance/`, the script must write modules to `~/openshift-docs/modules/`, not `~/openshift-docs/scalability_and_performance/modules/`. The `-o` flag tells the script to use the repository root as the base path.

## Advanced Usage

### Batch Processing with Error Handling

```bash
#!/bin/bash
# batch_process.sh

file_list="assembly_list.txt"
output_dir="$HOME/imploded_for_dita"

# Implode all assemblies
while IFS= read -r assembly; do
  echo "Processing: $assembly"
  ./implode-assembly.sh -q "$assembly" || {
    echo "ERROR: Failed to implode $assembly"
    continue
  }
done < "$file_list"

echo "All assemblies imploded. Run DITA validation, then use explode-assembly.sh to extract changes."
```

### Integration with DITA Validation

```bash
#!/bin/bash
# validate_and_report.sh

imploded_file="$1"

if [[ ! -f "$imploded_file" ]]; then
  echo "Usage: $0 <imploded_file>"
  exit 1
fi

# Run validation
validation_output="${imploded_file%.txt}_validation.txt"
dita-vale "$imploded_file" > "$validation_output"

# Show summary
echo "Validation complete. Results:"
grep -c "ERROR" "$validation_output" && echo "Errors found" || echo "No errors"
grep -c "WARNING" "$validation_output" && echo "Warnings found" || echo "No warnings"

echo "Full report: $validation_output"
```

## Summary

This workflow provides a safe, reversible way to:
1. Consolidate complex multi-file assemblies for validation
2. Fix DITA conversion issues in a single location
3. Automatically distribute fixes back to source files
4. Maintain git history and traceability

The scripts handle the complexity of nested includes and preserve the structure needed to reverse the process accurately.

## Final Deliverables Checklist

After completing the full workflow, you should have:

### ✅ On GitHub (your deliverables):
- [ ] Updated `assemblies/*.adoc` files with DITA-compatible fixes
- [ ] Updated `modules/*.adoc` files with DITA-compatible fixes
- [ ] Updated `snippets/*.adoc` files with DITA-compatible fixes
- [ ] Git commit with clear message about DITA conversion fixes
- [ ] All files ready for clean DITA XML conversion

### ✅ In Your Working Directory:
- [ ] Original files have `.bak` backups (created by explode script)
- [ ] `git diff` shows only intentional DITA-compatibility changes
- [ ] `asciibinder build` completes successfully
- [ ] Documentation renders correctly in preview

### 🗑️ Can Be Deleted (temporary files):
- [ ] `~/imploded_assemblies/*.txt` - Large combined files (workspace only)
- [ ] Validation report files (if no longer needed)
- [ ] `.bak` backup files (after confirming changes are correct)

### 🎯 Mission Accomplished:
Your individual AsciiDoc files are now DITA-compatible and committed to GitHub, ready for seamless DITA XML conversion!
