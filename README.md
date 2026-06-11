# Ez CHD Management Tools

A suite of lightweight Bash shell utilities designed for efficiently auditing and creating Compressed Hunks of Data (CHD) files.<br>
These tools leverage mame-tools to automate bulk conversions and validate collection integrity against official Redump DAT files.<br>

**Utilities Overview**<br>

```
ezchdchk.sh: Audits CHD files (CD/DVD) against a Redump.org XML DAT file, identifying matches, missing tracks, or files requiring renaming/moving.
ezchdiso.sh: Batch converts standard .iso DVD images into CHD format (createdvd).
ezchdzip.sh: Extracts zipped archives containing .iso or .cue/.bin files into shared memory (/dev/shm), converts them to CHD (createcd or createdvd), and cleans up the temporary files.
```

**Prerequisites & Installation**<br>

Ensure you have the necessary packages installed on your Linux system.<br>

Required Runtime Dependencies:<br>

```
mame-tools (provides chdman)
sha1sum (for image hashing)
util-linux (provides column for log formatting)
coreutils (provides realpath)
unzip (required by ezchdzip)
7zip (required by ezchdzip)
```

**Quick Setup**<br>

Save the scripts to your directory of choice (e.g., ~/bin/ or the directory with your games).<br>
Make the scripts executable:<br>

#### Syntax
```bash
chmod +x ezchdchk.sh ezchdiso.sh ezchdzip.sh
```
Usage Guide:<br>

## ezchdchk — Collection Auditor

Validates your CHD collection against an official Redump data sheet. It extracts files temporarily to shared memory (`/dev/shm`) to perform SHA-1 verification without burning through SSD write cycles.<br>

#### Syntax
```bash
./ezchdchk.sh [datfile] [workdir] [params]
```

Parameters (Comma-separated, no spaces):<br>

* ***rename***: Automatically renames the CHD file if its hashes perfectly match a entry in the DAT but the file name is mismatched.<br>
* ***move***: Moves unrecognized CHDs ([MISS]) into a subfolder named after their status inside your working directory.<br>
* ***ignorefix***: Excludes incomplete ([FIXME]) entries from log reporting.<br>
* ***verbose***: Appends individual track-by-track SHA-1 validation logs beneath the primary game status in the report.<br>

Output Status Indicators:

**[MATCH]**: File is 100% verified against the DAT entry.<br>
**[RENAME]**: Contents match an entry perfectly, but the filename is incorrect.<br>
**[FIXME]**: Matches a game signature, but track counts or hashes have discrepancies.<br>
**[MISS]**: No matching SHA-1 signature found in the provided DAT.<br>

#### Example
```bash
./ezchdchk.sh /path/to/sony_ps2_redump.dat /home/user/Games/PS2/ rename,verbose
```

Note: Detailed tabular reports are automatically saved to ./logs/[DAT_NAME].log.<br>

## ezchdiso — ISO to CHD Batch Converter

Scans a source directory for uncompressed .iso files and processes them into space-saving CHDs.<br>

#### Syntax
```bash
./ezchdiso.sh [workdir] [destdir] [params]
```

Parameters (Comma-separated, no spaces):<br>

* ***delete***: Automatically deletes the original source .iso file only if the target .chd was successfully created.<br>

#### Example
```bash
./ezchdiso.sh /home/user/Downloads/RawIsos /home/user/Games/PS2 delete
```

## ezchdzip — Zip/7zip to CHD Archive Converter

Automates the tedious task of converting compressed .zip and .7z archives containing either CD formats (CUE+BIN) or DVD formats (ISO) straight into ready-to-use CHDs.<br>

#### Syntax
```bash
./ezchdzip.sh [workdir] [destdir] [params]
```

Parameters (Comma-separated, no spaces):<br>

* ***delete***: Automatically deletes the original source .zip and .7z archive only if the target .chd file was successfully verified on disk.<br>

#### Example
```bash
./ezchdzip.sh /home/user/Downloads/ZippedGames /home/user/Games/PSX delete
```

## Important System Notes

* **Temporary Storage**: Both ezchdchk and ezchdzip make use of RAM-backed storage via /dev/shm. This guarantees blazing-fast extraction and hashing performance while reducing storage drive wear.<br>
* **RAM Capacity Warning**: Ensure you have enough free RAM allocated to /dev/shm to match the size of the uncompressed games you are processing (especially critical for large DVD-based images).<br>

***2026, manliodp***<br>
