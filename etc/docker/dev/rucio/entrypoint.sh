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
    
    # Note: editable installs do NOT install data_files, so we need to copy them manually
    # Copy data files from source to expected locations
    echo "Copying data files from source (editable installs don't include data_files)"
    
    # Copy mail templates
    if [ -d "$RUCIO_SOURCE_DIR/etc/mail_templates" ]; then
        mkdir -p "$RUCIO_HOME/etc/mail_templates"
        cp -r "$RUCIO_SOURCE_DIR/etc/mail_templates"/* "$RUCIO_HOME/etc/mail_templates/"
        echo "Copied mail templates from source"
    fi
    
    # Copy JSON configuration files
    for json_file in "$RUCIO_SOURCE_DIR/etc"/*.json; do
        if [ -f "$json_file" ]; then
            cp "$json_file" "$RUCIO_HOME/etc/"
            echo "Copied $(basename "$json_file") from source"
        fi
    done
    
    # Copy template files
    for template_file in "$RUCIO_SOURCE_DIR/etc"/*.template; do
        if [ -f "$template_file" ]; then
            cp "$template_file" "$RUCIO_HOME/etc/"
            echo "Copied $(basename "$template_file") from source"
        fi
    done
    
    # Copy test files
    if [ -f "$RUCIO_SOURCE_DIR/tools/test.file.1000" ]; then
        mkdir -p "$RUCIO_HOME/tools"
        cp "$RUCIO_SOURCE_DIR/tools/test.file.1000" "$RUCIO_HOME/tools/"
        echo "Copied test.file.1000 from source"
    fi
    
    # Copy essential tools
    for tool in bootstrap.py reset_database.py merge_rucio_configs.py; do
        if [ -f "$RUCIO_SOURCE_DIR/tools/$tool" ]; then
            mkdir -p "$RUCIO_HOME/tools"
            cp "$RUCIO_SOURCE_DIR/tools/$tool" "$RUCIO_HOME/tools/"
            echo "Copied $tool from source"
        fi
    done
fi

exec "$@"
