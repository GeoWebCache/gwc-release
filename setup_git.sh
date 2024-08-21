#!/bin/bash
# Exit on error
set -e

# Configure Git username and email if provided
if [ -n "$GIT_USERNAME" ]; then
    git config --global user.name "$GIT_USERNAME"
fi

if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL"
fi

exec /bin/bash
