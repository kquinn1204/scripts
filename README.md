# scripts

Disclaimer: I can't fully vouch for the quality of these scripts,
which were generated with AI chatbot assistance. If
you are a human with feedback, feel free to ping me on 
Slack!

I created these scripts with CCS goals in mind (such
as performing Content Quality Assessments), and you
are welcome to use them. 

### important

This script is based on the structure of the openshift-docs
repo. If your repo structure is different, you might need
to make changes to your copy of the script.

Also, the current version of this script probably can't handle ifevals around module include statements... sorry!

## implode-assembly.sh

**implode-assembly.sh** prepares documentation for use
with AI such as NotebookLM by "inlining" the contents
of included modules/snippets while retaining the
assembly context. This way, the AI can also analyze
the markup/raw files in addition to the content.

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

### Features

- **Nested assembly support**: The script now recursively inlines nested assemblies and modules
- **Multiple file processing**: Process individual files, directories, or files from a list
- **Flexible output**: Create individual files or combine all assemblies into a single file
- **Preserves context**: Maintains original `include::` statements alongside inlined content
- **AI-ready format**: Optimized for analysis by AI tools like NotebookLM
