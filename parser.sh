#!/usr/bin/env bash
# ==============================================================================
# parser.sh
# ==============================================================================
# Enterprise Bash script to fetch S&P 500 constituents CSV data, parse company
# metadata (Company Name, Headquarters, Founded Year), filter records, sort by
# Founded Year ascending, and display aligned column output.
#
# Requirements: bash, curl/wget, awk, sort, mktemp
# Usage: ./parser.sh
# ==============================================================================

set -euo pipefail

# Const Definitions
readonly DATA_URL="https://raw.githubusercontent.com/datasets/s-and-p-500-companies/refs/heads/main/data/constituents.csv"
readonly SCRIPT_NAME="$(basename "$0")"

# Global Temporary File Variables
TMP_DIR=""
RAW_CSV_FILE=""
PARSED_DATA_FILE=""

# ==============================================================================
# Helper & Cleanup Functions
# ==============================================================================

log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
        log_info "Cleaned up temporary workspace."
    fi
}

# Trap exit signals for reliable resource cleanup
trap cleanup EXIT INT TERM

check_dependencies() {
    local missing_deps=()

    if ! command -v awk >/dev/null 2>&1; then
        missing_deps+=("awk")
    fi
    if ! command -v sort >/dev/null 2>&1; then
        missing_deps+=("sort")
    fi
    if ! command -v mktemp >/dev/null 2>&1; then
        missing_deps+=("mktemp")
    fi
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_deps+=("curl or wget")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# ==============================================================================
# Core Pipeline Functions
# ==============================================================================

setup_temp_workspace() {
    TMP_DIR="$(mktemp -d -t csv_parser_XXXXXX)"
    RAW_CSV_FILE="${TMP_DIR}/constituents.csv"
    PARSED_DATA_FILE="${TMP_DIR}/parsed_results.txt"
}

download_csv() {
    local url="$1"
    local dest="$2"

    log_info "Fetching CSV data from ${url}..."

    if command -v curl >/dev/null 2>&1; then
        if ! curl -sSL --fail --connect-timeout 15 --max-time 30 "$url" -o "$dest"; then
            log_error "curl download failed for URL: $url"
            exit 2
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q --timeout=15 -O "$dest" "$url"; then
            log_error "wget download failed for URL: $url"
            exit 2
        fi
    else
        log_error "Neither curl nor wget is available."
        exit 1
    fi

    # Validate file existence and size
    if [[ ! -s "$dest" ]]; then
        log_error "Downloaded CSV file is empty or missing."
        exit 3
    fi

    log_info "Successfully downloaded CSV file ($(wc -l < "$dest" | tr -d ' ') lines)."
}

process_csv() {
    local input_file="$1"
    local output_file="$2"

    log_info "Parsing CSV content and extracting company fields..."

    awk '
    # Pure AWK State Machine CSV Parser
    function parse_csv_line(line, fields,   i, c, in_quote, field, len, field_idx) {
        delete fields
        len = length(line)
        in_quote = 0
        field = ""
        field_idx = 1
        
        for (i = 1; i <= len; i++) {
            c = substr(line, i, 1)
            if (c == "\"") {
                if (in_quote && substr(line, i+1, 1) == "\"") {
                    field = field "\""
                    i++
                } else {
                    in_quote = !in_quote
                }
            } else if (c == "," && !in_quote) {
                fields[field_idx++] = field
                field = ""
            } else {
                field = field c
            }
        }
        fields[field_idx] = field
        return field_idx
    }

    BEGIN {
        count = 0
    }

    {
        # Skip header row
        if (NR == 1) next;

        # Clean carriage returns from Windows CRLF
        sub(/\r$/, "", $0)
        if (length($0) == 0) next;

        num_fields = parse_csv_line($0, fields)

        # Ensure we have at least 8 fields (Symbol, Security, GICS Sector, GICS Sub-Industry, HQ, Date, CIK, Founded)
        if (num_fields < 8) next;

        company = fields[2]
        hq = fields[5]
        founded_raw = fields[8]

        # Trim leading/trailing whitespace
        sub(/^[ \t]+/, "", company); sub(/[ \t]+$/, "", company)
        sub(/^[ \t]+/, "", hq); sub(/[ \t]+$/, "", hq)
        sub(/^[ \t]+/, "", founded_raw); sub(/[ \t]+$/, "", founded_raw)

        # Extract 4-digit founded year
        year = ""

        # Handle cases like "2013 (1888)" where original founded year is in parentheses
        if (match(founded_raw, /\(([0-9]{4})\)/)) {
            year = substr(founded_raw, RSTART + 1, 4)
        } else if (match(founded_raw, /[0-9]{4}/)) {
            year = substr(founded_raw, RSTART, 4)
        }

        # Ignore record if Founded Year is missing or non-numeric
        if (year == "" || year !~ /^[0-9]{4}$/) {
            next;
        }

        if (company != "" && hq != "") {
            print year "|" company "|" hq
            count++
        }
    }

    END {
        # Log to stderr
        print "[INFO] Extracted " count " valid company records with founded years." > "/dev/stderr"
    }
    ' "$input_file" > "$output_file"
}

format_and_display() {
    local input_file="$1"

    log_info "Sorting data by Founded Year (ascending) and formatting aligned columns..."

    # Sort numerically by first column (Founded Year)
    local sorted_data
    sorted_data="$(sort -t'|' -k1,1n "$input_file")"

    # Print Header & Formatted Table using AWK column width alignment
    echo "$sorted_data" | awk '
    BEGIN {
        FS = "|"
        # Print Table Header
        printf "%-12s | %-40s | %-35s\n", "Founded Year", "Company", "Headquarters"
        printf "%-12s-+-%-40s-+-%-35s\n", "------------", "----------------------------------------", "-----------------------------------"
    }
    {
        year = $1
        company = $2
        hq = $3

        # Truncate overly long company or HQ strings for visual alignment if necessary
        if (length(company) > 40) company = substr(company, 1, 37) "..."
        if (length(hq) > 35) hq = substr(hq, 1, 32) "..."

        printf "%-12s | %-40s | %-35s\n", year, company, hq
    }
    '
}

# ==============================================================================
# Main Orchestrator
# ==============================================================================

main() {
    check_dependencies
    setup_temp_workspace
    download_csv "$DATA_URL" "$RAW_CSV_FILE"
    process_csv "$RAW_CSV_FILE" "$PARSED_DATA_FILE"
    format_and_display "$PARSED_DATA_FILE"
}

main "$@"
