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

# Print debug information
echo "Current directory: $(pwd)"
echo "RUCIO_SOURCE_DIR: $RUCIO_SOURCE_DIR"
echo "PYTHONPATH: $PYTHONPATH"

CFG_PATH="$RUCIO_SOURCE_DIR"/etc/docker/test/extra/
if [ -z "$RUCIO_HOME" ]; then
    RUCIO_HOME=/opt/rucio
fi

mkdir -p "$RUCIO_HOME/etc"

generate_rucio_cfg(){
  	local override=$1
  	local destination=$2

    python3 $RUCIO_SOURCE_DIR/tools/merge_rucio_configs.py --use-env \
        -s "$CFG_PATH"/rucio_autotests_common.cfg "$override" \
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
    cp "$CFG_PATH"/rucio_default.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_default.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "oracle" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_oracle.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_oracle.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "mysql8" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_mysql8.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_mysql8.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "sqlite" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_sqlite.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_sqlite.ini $RUCIO_HOME/etc/alembic.ini

elif [ "$RDBMS" == "postgres14" ]; then
    generate_rucio_cfg "$CFG_PATH"/rucio_postgres14.cfg $RUCIO_HOME/etc/rucio.cfg
    cp "$CFG_PATH"/alembic_postgres14.ini $RUCIO_HOME/etc/alembic.ini

fi

# Install Rucio from mounted source in editable mode
if [ -d "$RUCIO_SOURCE_DIR" ]; then
    echo "Installing Rucio from mounted source code at $RUCIO_SOURCE_DIR"
    echo "Source directory contents:"
    ls -la "$RUCIO_SOURCE_DIR"
    
    # Make sure we're in the source directory
    cd "$RUCIO_SOURCE_DIR"
    
    # Install in editable mode
    python3 -m pip install -e .[oracle,postgresql,mysql,kerberos,saml,dev]
    
    # Verify installation
    echo "Checking if rucio module can be imported..."
    python3 -c "import sys; print(sys.path); import rucio; print(f'Rucio module found at: {rucio.__file__}')" || echo "Failed to import rucio module"
    
    # Explicitly add to PYTHONPATH if needed
    if [ -z "$PYTHONPATH" ] || [[ "$PYTHONPATH" != *"$RUCIO_SOURCE_DIR"* ]]; then
        export PYTHONPATH="$RUCIO_SOURCE_DIR:$PYTHONPATH"
        echo "Updated PYTHONPATH: $PYTHONPATH"
    fi
    
    echo "Rucio installed successfully in editable mode"
else
    echo "ERROR: Rucio source directory not found at $RUCIO_SOURCE_DIR"
    exit 1
fi

update-ca-trust

# Create a .pth file in the site-packages directory to ensure rucio is in the Python path
SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
echo "$RUCIO_SOURCE_DIR" > "$SITE_PACKAGES/rucio.pth"
echo "Created rucio.pth in $SITE_PACKAGES"

# Create a symlink to the lib directory in site-packages
if [ -d "$RUCIO_SOURCE_DIR/lib" ]; then
    echo "Creating symlink from $SITE_PACKAGES/rucio to $RUCIO_SOURCE_DIR/lib/rucio"
    if [ -d "$RUCIO_SOURCE_DIR/lib/rucio" ]; then
        # Create symlink to the rucio module
        ln -sf "$RUCIO_SOURCE_DIR/lib/rucio" "$SITE_PACKAGES/rucio"
        echo "Symlink created successfully"
        
        # Verify the symlink
        if [ -L "$SITE_PACKAGES/rucio" ]; then
            echo "Symlink exists at $SITE_PACKAGES/rucio -> $(readlink -f $SITE_PACKAGES/rucio)"
        else
            echo "Failed to create symlink"
        fi
    else
        echo "Error: $RUCIO_SOURCE_DIR/lib/rucio directory not found"
    fi
else
    echo "Error: $RUCIO_SOURCE_DIR/lib directory not found"
fi

# Export PYTHONPATH for child processes
export PYTHONPATH="$RUCIO_SOURCE_DIR:$PYTHONPATH"

exec "$@"
