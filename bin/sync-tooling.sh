#!/bin/bash
# Roll the canonical tooling (tooling/) out to a plugin repository. See bin/sync-tooling.py.
exec python3 "$(dirname "$0")/sync-tooling.py" "$@"
