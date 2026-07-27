# S&P 500 Company CSV Parser 🏢

An enterprise-grade, portable Bash shell project that automatically downloads, parses, filters, and formats S&P 500 company constituent data sorted chronologically by founding year.

Designed using modular Bash standards, strict runtime safety (`set -euo pipefail`), signal trapping for automatic cleanup, quote-aware AWK CSV parsing, and aligned column formatting.

---

## 🌟 Key Features

- **Pure Bash Implementation**: Built exclusively with standard Unix utilities (`curl`/`wget`, `awk`, `sed`, `sort`, `mktemp`). No external Python/Ruby/Node dependencies.
- **Strict Error Handling**: Operates under `set -euo pipefail` to catch unhandled errors, unset variables, and pipeline failures.
- **Quote-Aware CSV Engine**: Custom AWK state-machine parser handles complex CSV edge cases like embedded commas inside quotes (e.g. `"Saint Paul, Minnesota"`).
- **Intelligent Year Extraction**: Normalizes founding years, handling complex patterns (e.g., extracting `1888` from `2013 (1888)`). Ignores records with missing founding dates.
- **Safe Temporary Files**: Uses `mktemp` and signal trapping (`trap cleanup EXIT INT TERM`) to guarantee zero leftover files on exit or interrupt.
- **Fallback Downloader**: Automatically attempts download via `curl` with a seamless fallback to `wget`.
- **Aligned Table Output**: Formats output into clean, human-readable table columns sorted by Founded Year in ascending order.

---

## 🛠️ Prerequisites & Dependencies

The script is compatible with any standard Linux/POSIX shell environment (Ubuntu, Debian, RHEL, macOS, Git Bash / WSL).

Required Unix utilities:
- `bash` (v4.0+)
- `curl` (or `wget`)
- `awk`
- `sort`
- `mktemp`

---

## 🚀 Execution & Usage

### 1. Grant Executable Permission
```bash
chmod +x parser.sh
```

### 2. Execute Script
```bash
./parser.sh
```

### 3. Save Output to File (Optional)
```bash
./parser.sh > output.txt
```

---

## 📊 Expected Output Example

When executed, diagnostic messages are logged to `stderr` while the structured table is printed to `stdout`:

```text
[INFO] Fetching CSV data from https://raw.githubusercontent.com/datasets/s-and-p-500-companies/refs/heads/main/data/constituents.csv...
[INFO] Successfully downloaded CSV file (504 lines).
[INFO] Parsing CSV content and extracting company fields...
[INFO] Extracted 503 valid company records with founded years.
[INFO] Sorting data by Founded Year (ascending) and formatting aligned columns...

Founded Year | Company                                  | Headquarters                       
-------------+------------------------------------------+------------------------------------
1784         | BNY Mellon                               | New York City, New York            
1792         | State Street Corporation                 | Boston, Massachusetts              
1802         | DuPont                                   | Wilmington, Delaware               
1806         | Colgate-Palmolive                        | New York City, New York            
1810         | Hartford (The)                           | Hartford, Connecticut              
1818         | Bunge Global                             | Chesterfield, Missouri             
...
2023         | Solventum                                | Saint Paul, Minnesota              
2024         | GE Vernova                               | Cambridge, Massachusetts           
2025         | Qnity Electronics                        | Wilmington, Delaware               
[INFO] Cleaned up temporary workspace.
```

---

## 💡 Assumptions & Edge Case Handling

1. **Embedded Quotes & Commas**: CSV fields containing location names with commas (e.g. `"San Francisco, California"`) are parsed without misaligning column indexes.
2. **Complex Founding Years**: For entries with re-incorporation dates like `2013 (1888)`, the script extracts the 4-digit year inside parentheses (`1888`) or the primary 4-digit numeric string.
3. **Missing Data Handling**: Records missing a valid 4-digit founding year are silently omitted from the sorted output.
4. **Network Failures**: Validates HTTP status codes and file size; aborts cleanly with exit code `2` on network or download failures.

---

## 📁 Project Structure

```
csv-company-parser/
│
├── parser.sh           # Main executable shell script
├── sample_output.txt   # Verified output generated from dataset
├── README.md           # Documentation & execution instructions
└── .gitignore          # Git exclusion rules
```

