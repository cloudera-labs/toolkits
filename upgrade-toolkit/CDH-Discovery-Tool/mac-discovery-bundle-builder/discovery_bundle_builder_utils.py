# Copyright 2022 Cloudera, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
import os
import os.path
import subprocess
import tarfile
from pathlib import Path

root_path = os.path.dirname(os.path.realpath(__file__))
log = logging.getLogger('main')


def create_directory(dir_path):
    path = Path(dir_path)
    if not os.path.exists(dir_path):
        log.debug(f"Creating directory: {dir_path}")
        path.mkdir(parents=True, exist_ok=True)


def _make_tarfile(output_file_path, source_dir, exclude=None):
    log.info("Creating tarball at " + output_file_path + " from " + source_dir)
    files = os.listdir(source_dir)
    log.debug("Files: {}".format(' '.join(map(str, files))))
    with tarfile.open(output_file_path, "w:gz") as tar:
        for f in files:
            tar.add(os.path.join(source_dir, f),
                    os.path.basename(f))
    log.info("Tarball created at: %s" % output_file_path)


def run_cmd(args_list):
    """
    run linux commands
    """
    # import subprocess
    result = subprocess.run(args_list)
    s_output = result.stdout
    s_err = result.stderr
    s_return = result.returncode
    log.info(f"Executed system command: {' '.join(args_list)}")
    if s_output:
        log.debug(f"STDOUT: {s_output}")
    if s_err:
        if args_list[0] == 'hdfs' and s_return == 0: # hdfs client by default writes everything to STDERR, causing false positive ERROR messages in log if not manually changed to debug
            log.debug(f"STDERR: {s_err}")
        else:
            log.error(f"STDERR: {s_err}")
    return s_return, s_output, s_err


def check_if_dir_exists(hdfs_config_dir, target_dir):
    (ret, out, err) = run_cmd(['hdfs', '--config', hdfs_config_dir, 'dfs', '-test', '-d', target_dir])
    dir_exits = ret == 0
    log.info(f"Target directory {target_dir} exits in HDFS: {dir_exits}")
    return dir_exits


def copy_to_local(src_hdfs_dir, output_dir, hdfs_config_dir):
    path = Path(output_dir)
    path.mkdir(parents=True, exist_ok=True)
    run_cmd(['hdfs', '--config', hdfs_config_dir, 'dfs', '-get', src_hdfs_dir, output_dir])


def retrieve_hdfs_username_group(hdfs_config_dir):
    log.debug("Retrieving HDFS username and groups")
    run_cmd(['hdfs', '--config', hdfs_config_dir, 'groups'])
