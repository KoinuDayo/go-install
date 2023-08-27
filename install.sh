#!/usr/bin/bash

# Copy from https://github.com/XTLS/Xray-install
identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='386'
        ;;
      'amd64' | 'x86_64')
        MACHINE='amd64'
        ;;
      'armv5tel')
        MACHINE='arm'
        ;;
      'armv6l')
        MACHINE='arm'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64'
        ;;
      'mips')
        MACHINE='mips'
        ;;
      'mipsle')
        MACHINE='mipsle'
        ;;
      'mips64')
        MACHINE='mips64'
        lscpu | grep -q "Little Endian" && MACHINE='mips64le'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
     elif [[ "$(type -P emerge)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='emerge -qv'
      PACKAGE_MANAGEMENT_REMOVE='emerge -Cv'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

# Copy from https://github.com/XTLS/Xray-install
install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" > /dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name" >/dev/null 2>&1; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[1;31m\033[1mERROR:\033[0m You have to use root to run this script"
        exit 1
    fi
}

curl() {
            # Copy from https://github.com/XTLS/Xray-install
    if ! $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@";then
        echo -e "\033[1;31m\033[1mERROR:\033[0m Curl Failed, check your network"
        exit 1
    fi
}

install_go() {
    [[ $MACHINE == 386 ]] && GO_MACHINE=386
    [[ $MACHINE == amd64 ]] && GO_MACHINE=amd64
    [[ $MACHINE == arm ]] && GO_MACHINE=armv6l
    [[ $MACHINE == arm64 ]] && GO_MACHINE=arm64
    [[ -z $REPLAYCE_PATH ]] && REPLAYCE_PATH=/usr/lib
    if [[ $GO_MACHINE == amd64 ]] || [[ $GO_MACHINE == arm64 ]] || [[ $GO_MACHINE == armv6l ]] || [[ $GO_MACHINE == 386 ]]; then
        echo -e "INFO: Installing GO" 
        curl -o /tmp/go.tar.gz https://go.dev/dl/go$GO_VERSION.linux-$GO_MACHINE.tar.gz
        rm -rf $REPLAYCE_PATH/go # && echo -e "DEBUG: Deleted current GO"
        tar -C $REPLAYCE_PATH -xzf /tmp/go.tar.gz # && echo -e "DEBUG: Replaced GO"
        rm /tmp/go.tar.gz
        ln -sf $REPLAYCE_PATH/go/bin/go /usr/sbin/go # && echo -e "DEBUG: Soft link created"
        go version
        GO_PATH=$(type -P go)
    else
        echo "\033[1;31m\033[1mERROR:\033[0m The architecture is not supported. Try to install go by yourself."
        exit 1
    fi
    echo -e "INFO: go installed PATH: $GO_PATH (soft symbolic link) PATH: $(readlink $GO_PATH)"
}

uninstall_go() {
    rm -rf $REPLAYCE_PATH/go && echo "Removed: $REPLAYCE_PATH/go"
    rm -rf $GO_PATH && echo "Removed: $GO_PATH"
    exit 0
}

find_go() {
  if [[ $PACKAGE_MANAGEMENT_INSTALL == 'apt -y --no-install-recommends install' ]]; then
    if dpkg -l | awk '{print $2"\t","Version="$3,"ARCH="$4}' | grep golang ;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Finded GO installed by package manager.\nExiting"
      exit 1
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'dnf -y install' ]]; then
    if dnf list installed golang;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Finded GO installed by package manager.\nExiting"
      exit 1
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'yum -y install' ]]; then
    if yum list installed golang;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Finded GO installed by package manager.\nExiting"
      exit 1
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'zypper install -y --no-recommends' ]]; then
    if zypper se --installed-only golang;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Finded GO installed by package manager.\nExiting"
      exit 1
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'pacman -Syu --noconfirm' ]]; then
    if pacman -Q go;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Finded GO installed by package manager.\nExiting"
      exit 1
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'emerge -qv' ]]; then
    if emerge -p dev-lang/go;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Finded GO installed by package manager.\nExiting"
      exit 1
    fi
  fi
}

main() {
    check_root
    identify_the_operating_system_and_architecture
    find_go
    GO_VERSION=$(curl -sL https://golang.org/VERSION?m=text | head -1 | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
    if GO_PATH=$(type -P go);then

        INSTALLED_PATH=$(readlink -f $(type -P go))
        [[ ! $INSTALLED_PATH == $GO_PATH ]] && SOFT_LINK="$GO_PATH (symbolic link)"
        echo -e "GO Found, PATH: $SOFT_LINK PATH: $INSTALLED_PATH"

        [[ -z $REPLAYCE_PATH ]] && REPLAYCE_PATH=$(echo $INSTALLED_PATH | sed 's/\/go\/bin\/go$//' )

        if [[ $INSTALLED_PATH == $REPLAYCE_PATH ]];then
          echo -e "ERROR: Wrong GO_PATH=$REPLAYCE_PATH Found.\nExiting."
        fi
        
        [[ $REMOVE == true ]] && uninstall_go
        CURRENT_VERSION=$(go version | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -1)
        echo -e "INFO: Current GO version = $CURRENT_VERSION\nINFO: Upstream GO version = $GO_VERSION"
        if ! [[ $CURRENT_VERSION == $GO_VERSION ]];then
          install_go
          exit 0
        else
          if [[ $FORCE == true ]];then
            install_go
            exit 0
          fi
          echo -e "INFO: GO is up to date.\nExiting."
          exit 0
        fi
    else
        echo -e "INFO: No GO found in your machine.\nINFO: Upstream GO version = $GO_VERSION"
        [[ $REMOVE == true ]] && exit 1
        install_go
        exit 0
    fi
}

help() {
  echo -e "\
usage: install.sh ACTION [OPTION]...

ACTION:
remove                    Remove golang
help                      Show help (alias: -h|--help)
If no action is specified, then help will be selected.

OPTION:
  install:
    --force                   If it's specified, the scrpit will force install latest version of golang.
    --path=                   If it's specified, the scrpit will install latest version of golang to your specified path.
                                For example, if \`--path=/usr/lib\` is specified, the scrpit will install golang into \`/usr/lib/go\`
"
  exit 0
}

for arg in "$@"; do
  case $arg in
    --force)
      FORCE=true
      ;;
    --path=*)
      REPLAYCE_PATH="${arg#*=}"
      ;;
    remove)
      REMOVE=true
      ;;
    install)
      INSTALL=true
      ;;
    help|-h|--help)
      help
      ;;
  esac
done

$([[ $INSTALL == true ]] || [[ $REMOVE == true ]]) && main
help