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

# Install Rucio from the mounted source code if it exists and not already installed
if [ -d "$RUCIO_SOURCE_DIR" ] && ! python -c "import rucio" &>/dev/null; then
    echo "Installing Rucio from mounted source code at $RUCIO_SOURCE_DIR"
    
    # Set environment variables to prevent file creation issues
    export PYTHONDONTWRITEBYTECODE=1
    export PIP_NO_CACHE_DIR=1
    
    # Clean up any existing .egg-info directory
    rm -rf "$RUCIO_SOURCE_DIR/lib/rucio.egg-info" 2>/dev/null || true
    
    # Try direct editable install first
    echo "Running pip install -e $RUCIO_SOURCE_DIR"
    if pip install --no-cache-dir --no-build-isolation -e "$RUCIO_SOURCE_DIR" 2>/dev/null; then
        echo "Editable install successful"
    else
        echo "Editable install failed, using alternative approach..."
        
        # Alternative: Add the library path directly to Python path
        LIB_PATH="$RUCIO_SOURCE_DIR/lib"
        PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        SITE_PACKAGES="/opt/venv/lib/python${PYTHON_VERSION}/site-packages"
        
        # Create a .pth file to include the Rucio lib directory
        echo "$LIB_PATH" > "$SITE_PACKAGES/rucio-source.pth"
        echo "Added $LIB_PATH to Python path via .pth file"
        
        # Verify the installation
        if python -c "import rucio" 2>/dev/null; then
            echo "Rucio import successful via path addition"
        else
            echo "WARNING: Rucio import still failing"
        fi
    fi
fi

exec "$@"
