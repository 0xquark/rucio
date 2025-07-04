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
Script to debug Python module imports.
"""

import os
import sys
import site
import importlib.util

def print_separator(title):
    """Print a separator with a title."""
    print("\n" + "=" * 80)
    print(f" {title} ".center(80, "="))
    print("=" * 80 + "\n")

def main():
    """Main function to debug Python module imports."""
    print_separator("Environment Information")
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"PYTHONPATH: {os.environ.get('PYTHONPATH', 'Not set')}")
    print(f"RUCIO_SOURCE_DIR: {os.environ.get('RUCIO_SOURCE_DIR', 'Not set')}")
    
    print_separator("Python Path")
    for i, path in enumerate(sys.path):
        print(f"{i}: {path}")
    
    print_separator("Site Packages")
    for i, path in enumerate(site.getsitepackages()):
        print(f"{i}: {path}")
        # List .pth files in site-packages
        pth_files = [f for f in os.listdir(path) if f.endswith('.pth')]
        if pth_files:
            print(f"  .pth files:")
            for pth_file in pth_files:
                print(f"    - {pth_file}")
                with open(os.path.join(path, pth_file), 'r') as f:
                    content = f.read().strip()
                    print(f"      Content: {content}")
    
    print_separator("Trying to Import Rucio")
    try:
        import rucio
        print(f"Rucio imported successfully!")
        print(f"Rucio version: {getattr(rucio, '__version__', 'Unknown')}")
        print(f"Rucio path: {rucio.__file__}")
        print(f"Rucio package path: {os.path.dirname(rucio.__file__)}")
    except ImportError as e:
        print(f"Failed to import rucio: {e}")
        
        # Try to find rucio module
        print("\nSearching for rucio module...")
        rucio_source_dir = os.environ.get('RUCIO_SOURCE_DIR', '/usr/local/src/rucio')
        
        # Check if lib/rucio exists in RUCIO_SOURCE_DIR
        lib_path = os.path.join(rucio_source_dir, 'lib')
        if os.path.exists(lib_path):
            print(f"Found lib directory at {lib_path}")
            rucio_path = os.path.join(lib_path, 'rucio')
            if os.path.exists(rucio_path):
                print(f"Found rucio directory at {rucio_path}")
                # Try to import using spec
                try:
                    spec = importlib.util.spec_from_file_location("rucio", os.path.join(rucio_path, "__init__.py"))
                    if spec:
                        module = importlib.util.module_from_spec(spec)
                        spec.loader.exec_module(module)
                        print(f"Successfully imported rucio using spec!")
                    else:
                        print(f"Could not create spec for rucio")
                except Exception as e:
                    print(f"Error importing using spec: {e}")
            else:
                print(f"rucio directory not found in {lib_path}")
        else:
            print(f"lib directory not found in {rucio_source_dir}")
    
    print_separator("Trying to Import from rucio.db.sqla.session")
    try:
        from rucio.db.sqla.session import wait_for_database
        print("Successfully imported wait_for_database function!")
    except ImportError as e:
        print(f"Failed to import wait_for_database: {e}")

if __name__ == "__main__":
    main() 