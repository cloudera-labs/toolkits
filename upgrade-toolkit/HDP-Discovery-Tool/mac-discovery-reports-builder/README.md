## Discovery reports builder
Steps:


Install Python 3.8 and virtual env if not available on cluster node:

```shell
yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel && 
cd /usr/src && 
wget https://www.python.org/ftp/python/3.8.1/Python-3.8.1.tgz && 
tar xzf Python-3.8.1.tgz && 
cd Python-3.8.1 && 
./configure --enable-optimizations && 
make altinstall && 
rm -f /usr/src/Python-3.8.1.tgz && 
python3.8 -V &&
cd &&
echo "Python installation successfully finished"

```

Copy the project under /opt directory:

```
cd /opt
# Use git if the environment is not air gaped
yum -y install git
git clone <repo_url>
```

Go to the project directory:

```
cd /opt/mac-hdp-discovery-bundle-builder/
```

Create a new virtual environment inside the project directory:

```
python3.8 -m venv .venv
source .venv/bin/activate
```

Install the dependencies for the project:

- For environments with internet access:

```commandline
pip install --upgrade pip
pip install -r requirements.txt
```

- For environments without internet access use the prepacked dependencies:

```commandline
tar -zxf wheelhouse.tar.gz
 pip install -r wheelhouse/requirements.txt --no-index --find-links wheelhouse
```


Run the script

The Discovery reports builder creates an XLSX file based on the discovery bundle directory.

Usage:

```commandline
chmod +x mac_reports_builder.sh
./mac_reports_builder.sh --discovery-bundle-path=/tmp/output --reports-path=/tmp/reports
```

Configurable parameters:

```
Usage: mac_reports_builder.sh [options]

Options:
  -h, --help            show this help message and exit
  --discovery-bundle-path=<input_path>
                        Path where the Discovery bundle was exported.
  --reports-path=<output_path>
                        Path where the mac-discovery-bundle-report.xlsx file
                        should be exported.
```