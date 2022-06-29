# .bashrc

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
# Title: ~/.bashrc 
# Author: WKD
# Date: 14MAR14
# Purpose: This is a cusomized bashrc config file.

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# Set Java Home
export JAVA_HOME=/usr/java/default

# Set home paths for bin and sbin
export PATH=${PATH}:${HOME}/bin:${HOME}/sbin:${JAVA_HOME}/bin

# Set Terminal this prevents the error TERM Environment variable not set
export TERM=xterm

# Set terminal prompt
if [ ${UID} -eq 0 ]; then
	export PS1="\u@\h \W# "
else
	export PS1="\u@\h \W$ "
fi

# User specific aliases and functions
# Bash runtime environment
export HISTSIZE=100    # 500 is default
export HISTFILESIZE=400
export HISTTIMEFORMAT='%b %d %I:%M   '
export HISTCONTROL=ignoreboth   # ignoredups:ignorespace
export HISTIGNORE="h:history:pwd:exit:df:ls:ls -la:ll"

# Common Alias
alias ll="ls -lahG"
alias home=$(cd ~)
alias up=$(cd ..)
alias h=$(history)
