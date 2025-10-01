#!/bin/bash

# Script to add SUPABASE_ANON_KEY to Info.plist
# Run this script once to configure the Supabase key

PLIST_PATH="Voice-Notes-Info.plist"
KEY_NAME="SUPABASE_ANON_KEY"
KEY_VALUE="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJoZmhhdGV5cWRpeXNnb29pcXRkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3NDkxNjEsImV4cCI6MjA3NDMyNTE2MX0.wQXG_26AYWe-euRqtpCuU1BpJJ1jqQQkAAkZtAXZiL0"

if [ ! -f "$PLIST_PATH" ]; then
    echo "❌ Error: Info.plist not found at $PLIST_PATH"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check if key already exists
if /usr/libexec/PlistBuddy -c "Print :$KEY_NAME" "$PLIST_PATH" 2>/dev/null; then
    echo "✅ Key $KEY_NAME already exists in Info.plist"
    # Update the value
    /usr/libexec/PlistBuddy -c "Set :$KEY_NAME $KEY_VALUE" "$PLIST_PATH"
    echo "✅ Updated $KEY_NAME value"
else
    # Add the key
    /usr/libexec/PlistBuddy -c "Add :$KEY_NAME string $KEY_VALUE" "$PLIST_PATH"
    echo "✅ Added $KEY_NAME to Info.plist"
fi

echo ""
echo "Configuration complete! The Supabase anon key has been added to your Info.plist"
