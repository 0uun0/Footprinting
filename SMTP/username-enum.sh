#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <SMTP_SERVER> <WORDLIST>"
    exit 1
fi

SMTP_SERVER="$1"
WORDLIST="$2"
TEMP_WORDLIST="word_temp.txt"
BATCH_SIZE=5
RESULTS_FILE="smtp_results.txt"

# Ensure the wordlist file exists
if [ ! -f "$WORDLIST" ]; then
    echo "Error: Wordlist file '$WORDLIST' not found!"
    exit 1
fi

# Clear previous results
> "$RESULTS_FILE"

while true; do
    # Check if the wordlist is empty
    if [ ! -s "$WORDLIST" ]; then
        echo "All users tested. Exiting."
        break
    fi

    echo "Connecting to $SMTP_SERVER..."

    # Open a connection to the SMTP server
    {
        echo "EHLO example.com"
        sleep 1

        # Counter to track number of tries
        COUNT=0

        # Create a temporary wordlist to hold untested users
        > "$TEMP_WORDLIST"

        # Loop through the wordlist and send VRFY commands
        while read -r user; do
            echo "[*] Testing: $user"
            echo "VRFY $user"
            sleep 1.5  # Small delay to avoid flooding

            ((COUNT++))
            if [ "$COUNT" -ge "$BATCH_SIZE" ]; then
                break
            fi
        done < "$WORDLIST"

        echo "QUIT"
    } | nc "$SMTP_SERVER" 25 | tee temp_output.txt  # Capture responses

    # Process the output to determine valid users
    while read -r user; do
        if grep -q "252" temp_output.txt; then
            echo "[+] Valid User: $user" | tee -a "$RESULTS_FILE"
        else
            echo "[-] Invalid User: $user"
        fi
    done < <(head -n "$BATCH_SIZE" "$WORDLIST")

    # Remove tested users from the original wordlist
    tail -n +"$((BATCH_SIZE + 1))" "$WORDLIST" > "$TEMP_WORDLIST"
    mv "$TEMP_WORDLIST" "$WORDLIST"

    # Restart connection after every batch
    echo "Restarting connection after $BATCH_SIZE attempts..."
    sleep 3
done

# Clean up temp files
rm -f temp_output.txt
