# Assembly Implode/Explode Scripts

These scripts enable a workflow for preparing OpenShift AsciiDoc assemblies for DITA conversion validation and correction.

## Overview

The workflow allows you to:
1. **Implode** an assembly - combine all included modules/snippets into a single file
2. **Validate** with DITA-vale or other validation tools
3. **Edit** the combined file to fix DITA conversion issues
4. **Explode** back to original files - extract changes to original module/snippet files

**End Goal:** Individual `.adoc` files (assemblies, modules, snippets) that are DITA-compatible and ready to commit to GitHub. The large combined file is temporary workspace only.

## Quick Start

```bash
# 1. Implode assembly into single file
./implode-assembly.sh assemblies/my-assembly.adoc

# 2. Validate the imploded file
dita-vale ~/imploded_assemblies/assemblies/my-assembly_branch_v1.txt

# 3. Edit the imploded file to fix issues
code ~/imploded_assemblies/assemblies/my-assembly_branch_v1.txt

# 4. Explode back to original files
./explode-assembly.sh ~/imploded_assemblies/assemblies/my-assembly_branch_v1.txt

# 5. Verify and commit DITA-ready files
cd ~/openshift-docs
git diff
git add assemblies/ modules/ snippets/
git commit -m "Fix DITA conversion issues"
```

See [WORKFLOW.md](WORKFLOW.md) for complete documentation.

## Important Notes

**Disclaimer:** These scripts were created with AI chatbot assistance. If you have feedback, feel free to reach out!

**Requirements:**
- Based on openshift-docs repo structure - may need modifications for other repos
- Cannot handle ifevals around module include statements

## Scripts

### implode-assembly.sh

Combines an assembly and all included modules/snippets into a single file for validation.

_usage_

First, make the script executable:

```
$ chmod +x ./implode-assembly.sh
```

### Basic Usage

Run the script, passing one or more arguments:

```bash
$ ./implode-assembly.sh <path/to/assembly.adoc>

# or, to implode all assemblies in a directory:
$ ./implode-assembly.sh <path/to/directory>

# or, multiple files:
$ ./implode-assembly.sh file1.adoc file2.adoc directory/
```

The output is saved to a file in a directory called
`imploded_assemblies`. If the directory does not exist,
it is created. If you passed a directory as an argument,
all relevant directories are created in `imploded_assemblies`.

The imploded assembly document has a default filename
pattern of `<assembly>_<branch>_v<n>.txt`, where _n_
increments if a file already exists.

For example:

```
❯ ~/implode-assembly.sh virt/install/installing-virt.adoc
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Output file:    /Users/panousley/imploded_assemblies/installing-virt_main_v2.txt
 Source:         virt/install/installing-virt.adoc
 Timestamp:      2025-06-17 13:19:35
 Git branch:     main
 Modules:        3
   • modules/virt-installing-virt-operator.adoc
   • modules/virt-subscribing-cli.adoc
   • modules/virt-deploying-operator-cli.adoc
 Snippets:       0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Advanced Options

#### Quiet Mode

To suppress detailed output and only print a list of generated
files, run the command with the `-q` or `--quiet` flag:

```bash
❯ ~/implode-assembly.sh virt/install -q
Generated files:
/Users/panousley/imploded_assemblies/virt/install/installing-virt_main_v8.txt
/Users/panousley/imploded_assemblies/virt/install/uninstalling-virt_main_v8.txt
/Users/panousley/imploded_assemblies/virt/install/preparing-cluster-for-virt_main_v8.txt
```

#### File List Mode

Process multiple files from a text file using the `-f` or `--file-list` option.
Create a text file with one `.adoc` file path per line:

```bash
# Create a file list
$ cat > myfiles.txt <<EOF
installing/installing-aws.adoc
networking/configuring-ingress.adoc
storage/persistent-storage.adoc
EOF

# Process all files from the list
$ ./implode-assembly.sh -f myfiles.txt
```

Comments (lines starting with `#`) and empty lines in the file list are ignored.

#### Combined Output Mode

Combine multiple assemblies into a single output file using the `-c` or `--combined` option:

```bash
# Combine all assemblies from a directory into one file
$ ./implode-assembly.sh -c ~/all_assemblies.txt virt/install/

# Combine assemblies from a file list
$ ./implode-assembly.sh -c ~/combined.txt -f myfiles.txt

# Combine specific files
$ ./implode-assembly.sh --combined output.txt file1.adoc file2.adoc file3.adoc
```

In combined mode, all processed assemblies are appended to a single file with
clear separators between each assembly, making it easier to feed large amounts
of documentation to AI tools at once.

#### Option Combinations

All options can be combined:

```bash
# Quiet mode + file list + combined output
$ ./implode-assembly.sh -q -f myfiles.txt -c combined_output.txt
```

### Command Syntax

```
./implode-assembly.sh [OPTIONS] [FILES/DIRECTORIES...]

Options:
  -q, --quiet          Suppress detailed output, show only file paths
  -f, --file-list      Read .adoc file paths from a text file (one per line)
  -c, --combined       Combine all outputs into a single file instead of individual files

Examples:
  ./implode-assembly.sh assembly.adoc
  ./implode-assembly.sh -f filelist.txt
  ./implode-assembly.sh -q -f filelist.txt
  ./implode-assembly.sh -c combined.txt -f filelist.txt
  ./implode-assembly.sh --combined all_assemblies.txt file1.adoc file2.adoc directory/
```

**Features:**
- Recursively inlines nested assemblies and modules
- Multiple file processing (individual files, directories, or file lists)
- Flexible output (individual files or combined mode)
- Preserves context with original `include::` statements
- Adds `// BEGIN inlined:` and `// END inlined:` markers for extraction

**Output Location:** `~/imploded_assemblies/`

### explode-assembly.sh

Reverses the implode process by extracting edited content from an imploded file back to original source files.

**Usage:**

```bash
# Make the script executable
$ chmod +x ./explode-assembly.sh

# Basic usage (creates .bak backups)
$ ./explode-assembly.sh ~/imploded_assemblies/assemblies/my-assembly_branch_v1.txt

# Dry run (preview changes without writing files)
$ ./explode-assembly.sh -n imploded_file.txt

# Verbose output
$ ./explode-assembly.sh -v imploded_file.txt

# No backups
$ ./explode-assembly.sh --no-backup imploded_file.txt

# Override output directory
$ ./explode-assembly.sh -o ~/openshift-docs imploded_file.txt

# Combine options
$ ./explode-assembly.sh -n -v imploded_file.txt
```

**Features:**
- Parses `// BEGIN inlined:` and `// END inlined:` markers
- Extracts content for each module/snippet
- Handles nested includes correctly
- Creates backups by default (`.bak` suffix)
- Dry-run mode to preview changes
- Reconstructs assembly file without inlined content

## What You Deliver to GitHub

After completing the workflow, you commit:
- ✅ Updated `assemblies/*.adoc` files (DITA-compatible)
- ✅ Updated `modules/*.adoc` files (DITA-compatible)
- ✅ Updated `snippets/*.adoc` files (DITA-compatible)
- ❌ NOT the large combined text file (temporary workspace only)

## Complete Workflow Documentation

For detailed workflow instructions, examples, and troubleshooting, see [WORKFLOW.md](WORKFLOW.md)
