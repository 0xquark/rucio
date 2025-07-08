#!/bin/bash
# -*- coding: utf-8 -*-
# Copyright European Organization for Nuclear Research (CERN) since 2012
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CFG_PATH="$RUCIO_SOURCE_DIR/etc/docker/test/extra"
if [ -z "$RUCIO_HOME" ]; then
    RUCIO_HOME=/opt/rucio
fi

mkdir -p "$RUCIO_HOME/etc"

generate_rucio_cfg(){
  	local override=$1
  	local destination=$2

    python3 $RUCIO_SOURCE_DIR/tools/merge_rucio_configs.py --use-env \
        -s "$CFG_PATH/rucio_autotests_common.cfg" "$override" \
        -d "$destination"
}

if [ -f /tmp/usercert.pem ]; then
    cp /tmp/usercert.pem "$RUCIO_HOME/etc/"
fi
if [ -f /tmp/userkey.pem ]; then
    cp /tmp/userkey.pem "$RUCIO_HOME/etc/"
    chmod og-rwx "$RUCIO_HOME/etc/userkey.pem"
fi

echo "Generating alembic.ini and rucio.cfg"

if [ -z "$RDBMS" ]; then
    cp "$CFG_PATH/rucio_default.cfg" $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH/alembic_default.ini" $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "oracle" ]; then
    generate_rucio_cfg "$CFG_PATH/rucio_oracle.cfg" $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH/alembic_oracle.ini" $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "mysql8" ]; then
    generate_rucio_cfg "$CFG_PATH/rucio_mysql8.cfg" $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH/alembic_mysql8.ini" $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "sqlite" ]; then
    generate_rucio_cfg "$CFG_PATH/rucio_sqlite.cfg" $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH/alembic_sqlite.ini" $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "postgres14" ]; then
    generate_rucio_cfg "$CFG_PATH/rucio_postgres14.cfg" $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH/alembic_postgres14.ini" $RUCIO_HOME/etc/alembic.ini

fi

update-ca-trust

# Install Rucio from the mounted source code if not already installed
if [ -d "$RUCIO_SOURCE_DIR" ] && ! python -c "import rucio" &>/dev/null; then
    echo "Installing Rucio from mounted source code at $RUCIO_SOURCE_DIR"
    
    # Set environment variables to prevent file creation issues
    export PYTHONDONTWRITEBYTECODE=1
    export PIP_NO_CACHE_DIR=1
    
    # Install Rucio with editable mode (source code changes visible immediately)
    pip install --no-cache-dir -e "$RUCIO_SOURCE_DIR"
    
    # Note: editable installs do NOT install data_files, so we need to symlink them manually
    # Create symlinks from source to expected locations (so any PR changes are immediately visible)
    echo "Creating symlinks to data files from source (editable installs don't include data_files)"
    
    # Symlink mail templates directory
    if [ -d "$RUCIO_SOURCE_DIR/etc/mail_templates" ]; then
        mkdir -p "$RUCIO_HOME/etc"
        if [ -e "$RUCIO_HOME/etc/mail_templates" ]; then
            rm -rf "$RUCIO_HOME/etc/mail_templates"
        fi
        ln -sf "$RUCIO_SOURCE_DIR/etc/mail_templates" "$RUCIO_HOME/etc/mail_templates"
        echo "Symlinked mail_templates: $RUCIO_HOME/etc/mail_templates -> $RUCIO_SOURCE_DIR/etc/mail_templates"
    fi
    
    # Symlink individual JSON and template files
    mkdir -p "$RUCIO_HOME/etc"
    for file in "$RUCIO_SOURCE_DIR/etc"/*.json "$RUCIO_SOURCE_DIR/etc"/*.template; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            target="$RUCIO_HOME/etc/$filename"
            # Remove existing file/symlink to avoid circular links and "device busy" errors
            if [ -e "$target" ] || [ -L "$target" ]; then
                rm -f "$target"
            fi
            ln -sf "$file" "$target"
            echo "Symlinked: $target -> $file"
        fi
    done
    
    # Symlink tools directory (or create and symlink individual files)
    mkdir -p "$RUCIO_HOME/tools"
    for tool in test.file.1000 bootstrap.py reset_database.py merge_rucio_configs.py; do
        if [ -f "$RUCIO_SOURCE_DIR/tools/$tool" ]; then
            target="$RUCIO_HOME/tools/$tool"
            # Remove existing file/symlink to avoid circular links
            if [ -e "$target" ] || [ -L "$target" ]; then
                rm -f "$target"
            fi
            ln -sf "$RUCIO_SOURCE_DIR/tools/$tool" "$target"
            echo "Symlinked: $target -> $RUCIO_SOURCE_DIR/tools/$tool"
        fi
    done
    
    # Debug: Verify the symlinks were created correctly
    echo "DEBUG: Verifying symlinked files exist:"
    echo "DEBUG: Checking $RUCIO_HOME/etc/mail_templates/rule_approval_request.tmpl"
    ls -la "$RUCIO_HOME/etc/mail_templates/rule_approval_request.tmpl" 2>/dev/null || echo "DEBUG: rule_approval_request.tmpl NOT FOUND"
    echo "DEBUG: Checking $RUCIO_HOME/etc/automatix.json"
    ls -la "$RUCIO_HOME/etc/automatix.json" 2>/dev/null || echo "DEBUG: automatix.json NOT FOUND"
    echo "DEBUG: Checking $RUCIO_HOME/etc/google-cloud-storage-test.json"
    ls -la "$RUCIO_HOME/etc/google-cloud-storage-test.json" 2>/dev/null || echo "DEBUG: google-cloud-storage-test.json NOT FOUND"
fi

exec "$@"
