#!/usr/bin/sh
#
# ver 1.0


config=".my.cnf.$$"
command=".mysql.$$"

trap "interrupt" 1 2 3 6 15

rootpass="$1"
oldrootpass="$2"
basedir=
bindir=

find_in_basedir()
{
  return_dir=0
  found=0
  case "$1" in
    --dir)
      return_dir=1; shift
      ;;
  esac

  file=$1; shift

  for dir in "$@"
  do
    if test -f "$basedir/$dir/$file"
    then
      found=1
      if test $return_dir -eq 1
      then
        echo "$basedir/$dir"
      else
        echo "$basedir/$dir/$file"
      fi
      break
    fi
  done

  if test $found -eq 0
  then
      # Test if command is in PATH
      $file --no-defaults --version > /dev/null 2>&1
      status=$?
      if test $status -eq 0
      then
        echo $file
      fi
  fi
}

cannot_find_file()
{
  echo
  echo "FATAL ERROR: Could not find $1"

  shift
  if test $# -ne 0
  then
    echo
    echo "The following directories were searched:"
    echo
    for dir in "$@"
    do
      echo "    $dir"
    done
  fi

  echo
  echo "If you compiled from source, you need to run 'make install' to"
  echo "copy the software into the correct location ready for operation."
  echo
  echo "If you are using a binary release, you must either be at the top"
  echo "level of the extracted archive, or pass the --basedir option"
  echo "pointing to that location."
  echo
}

if test -n "$basedir"
then
  bindir="$basedir/bin"
elif test -f "./bin/mysql"
  then
  bindir="./bin"
else
  bindir="/usr/bin"
fi
mysql_command=`find_in_basedir mysql $bindir`
if test -z "$mysql_command"
then
  cannot_find_file mysql $bindir
  exit 1
fi

make_config() {
    echo "# mysql_secure_installation config file" >$config
    echo "[mysql]" >>$config
    echo "user=root" >>$config
    esc_pass="$1"
    echo "password='$esc_pass'" >>$config
    #sed 's,^,> ,' < $config  # Debugging
}

do_query() {
    echo "$1" >$command
    #sed 's,^,> ,' < $command  # Debugging
    $mysql_command --defaults-file=$config <$command
    return $?
}

set_root_password() {
	echo "! Set root password"
	do_query "UPDATE mysql.user SET Password=PASSWORD('$1') WHERE User='root';"
    if [ $? -eq 0 ]; then
        echo " ... Success!"
    else
        echo " ... Failed!"
        clean_and_exit
    fi

    return 0
}

remove_anonymous_users() {
	echo "! Remove anonymous users"
    do_query "DELETE FROM mysql.user WHERE User='';"
    if [ $? -eq 0 ]; then
        echo " ... Success!"
    else
        echo " ... Failed!"
        clean_and_exit
    fi

    return 0
}

remove_remote_root() {
	echo "! Remove remote root"
    do_query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    if [ $? -eq 0 ]; then
        echo " ... Success!"
    else
        echo " ... Failed!"
    fi
}

remove_test_database() {
    echo "! Dropping test database..."
    do_query "DROP DATABASE test;"
    if [ $? -eq 0 ]; then
        echo " ... Success!"
    else
        echo " ... Failed!  Not critical, keep moving..."
    fi

    echo " - Removing privileges on test database..."
    do_query "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    if [ $? -eq 0 ]; then
        echo " ... Success!"
    else
        echo " ... Failed!  Not critical, keep moving..."
    fi

    return 0
}

reload_privilege_tables() {
echo "! Reload privilege tables"
    do_query "FLUSH PRIVILEGES;"
    if [ $? -eq 0 ]; then
        echo " ... Success!"
        return 0
    else
        echo " ... Failed!"
        return 1
    fi
}

interrupt() {
    echo
    echo "Aborting!"
    echo
    cleanup
    stty echo
    exit 1
}

cleanup() {
    echo "Cleaning up..."
    rm -f $config $command
}

# Remove the files before exiting.
clean_and_exit() {
        cleanup
        exit 1
}

# The actual script starts here

make_config $oldrootpass
set_root_password $rootpass
remove_anonymous_users
remove_remote_root
remove_test_database
reload_privilege_tables

cleanup
