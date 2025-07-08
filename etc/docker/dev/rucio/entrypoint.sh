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

# Generate certificates if they don't exist (needed for mounting source etc/ dir)
if [ ! -f "$RUCIO_HOME/etc/rucio_ca.pem" ] || [ ! -f "$RUCIO_HOME/etc/ruciouser.pem" ] || [ ! -f "$RUCIO_HOME/etc/ruciouser.key.pem" ]; then
    echo "Generating test certificates..."
    cd "$RUCIO_SOURCE_DIR/etc/certs"
    bash generate.sh
    
    # Copy generated certificates to the expected location
    cp rucio_ca.pem "$RUCIO_HOME/etc/"
    cp ruciouser.pem "$RUCIO_HOME/etc/"
    cp ruciouser.key.pem "$RUCIO_HOME/etc/"
    cp ruciouser.certkey.pem "$RUCIO_HOME/etc/"
    
    # Set proper permissions
    chmod 0400 "$RUCIO_HOME/etc/ruciouser.key.pem"
    
    # Create certs subdirectory and symlink for compatibility
    mkdir -p "$RUCIO_HOME/etc/certs"
    ln -sf "$RUCIO_HOME/etc/rucio_ca.pem" "$RUCIO_HOME/etc/certs/rucio_ca.pem"
    
    echo "Test certificates generated successfully"
fi

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
    
    # Note: editable installs do NOT install data_files, but we mount etc/ and tools/ directly
    echo "Using mounted etc/ and tools/ directories from source (no symlinks needed)"
fi

exec "$@"
