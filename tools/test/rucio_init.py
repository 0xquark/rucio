#!/usr/bin/env python3
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

"""
This script helps Python find the rucio module.
It should be imported before any other rucio imports.
"""

import os
import sys
import site
import importlib.util

def ensure_rucio_in_path():
    """Ensure that the rucio module is in the Python path."""
    # Get the source directory from environment or use default
    source_dir = os.environ.get('RUCIO_SOURCE_DIR', '/usr/local/src/rucio')
    
    # Add source directory to Python path if not already there
    if source_dir not in sys.path:
        sys.path.insert(0, source_dir)
    
    # Check if lib directory exists
    lib_dir = os.path.join(source_dir, 'lib')
    if os.path.exists(lib_dir) and lib_dir not in sys.path:
        sys.path.insert(0, lib_dir)
    
    # Get site-packages directory
    site_packages = site.getsitepackages()[0]
    
    # Create a .pth file if it doesn't exist
    pth_file = os.path.join(site_packages, 'rucio.pth')
    if not os.path.exists(pth_file):
        with open(pth_file, 'w') as f:
            f.write(source_dir)
    
    # Create a symlink if it doesn't exist
    rucio_module_path = os.path.join(source_dir, 'lib', 'rucio')
    symlink_path = os.path.join(site_packages, 'rucio')
    if os.path.exists(rucio_module_path) and not os.path.exists(symlink_path):
        try:
            os.symlink(rucio_module_path, symlink_path)
        except (OSError, PermissionError):
            # If symlink creation fails, just print a message
            print(f"Could not create symlink from {rucio_module_path} to {symlink_path}")
    
    # Try to import rucio to verify
    try:
        import rucio
        return True
    except ImportError:
        return False

# Automatically ensure rucio is in path when this module is imported
ensure_rucio_in_path() 