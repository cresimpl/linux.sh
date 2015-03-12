#!/usr/bin/bash
#
#       Szymon Rozanski
#       sz.rozanski@gmail.com
#
#       Skrypt do instalacji usług w systemie z kolorowymi statusami bledow i logami.
#
#       ver: 1.0        data: 11.03.2015

step="0"
serror="0"

### PARAMETRY ###
#################
par=$*

### HELP ###
############

phelp=$(echo "$par" | grep -qse "--help" && echo 0 || echo 1)

help="
Skrypt do debugowania plikow z rozszerzeniem code.

SKLADNIA:

$(which $0) /path/to/*.code
$(which $0) /path/to/*.code <step number>
"

if [ "$1" = "" ]; then echo "$help"; exit 1; fi
if [ ! -e "$1" ]; then echo "$help"; exit 1; fi
if [ $phelp -eq 0 ]; then echo "$help"; exit 1; fi

### ZMIENNE SZABLONU ###
########################
if ! [ "$2" = "" ]; then continous="$2"; else continous=0; fi
adr_log_dir="/var/log/"
name="redmine"
adr_log_file="${adr_log_dir}service-${name}-instalation.log"
if [ -e $adr_log_file ]; then rm $adr_log_file; fi


# FUNKCJE SZABLONU #
####################

true() {
return 0
}

false() {
return 1
}

nextstep() {
((step++))
}

# KOLOR #
kolor() {
kolor=$1
shift 1
info=$*
case $kolor in
	"r") echo -e "\033[37;41m $info \033[37;40m";;
	"g") echo -e "\033[37;42m $info \033[37;40m";;
	"b") echo -e "\033[37;44m $info \033[37;40m";;
	"y") echo -e "\033[31;43m $info \033[37;40m";;
	*) echo inny
esac
}

# STATUS #
status() {
sufix="KOD: $?"
prefix="$(kolor y "#${step}#") $(date) =  STATUS:"
status=$1
shift 1
info=$1

case $status in
	"0") echo "$prefix $(kolor g $info) $sufix";;
	"1") echo "$prefix $(kolor r $info) $sufix";;
	"2") echo "$prefix $(kolor y $info) $sufix";;
	*) echo Bledny parametr dla funkcji status; exit 1
esac
}

# LOG #
log() {
name=$1
pipe=$(< /dev/stdin)
echo "$pipe" | tee -a $adr_log_file
}

# TITLE #
title() {
txt=$*

echo -e "$(kolor y $txt)" | log
echo -e "$(kolor r $(for ((i=0; i<${#txt}; i++)); do echo -n "-"; done))" | log
}

# HEAD #
head() {
txt=$*

echo "$(kolor b $txt)" | log
}

# BANNER #
banner() {
txt="$*"

echo -e "____________________________"
echo -e "   $(kolor y $txt)"
echo -e "____________________________"
}

# RUN #
#run <cmd>
#run <p1=save/add> <cmd1>
#run <p1=tee> <p2=adr for tee> <cmd2>
run() {
cmd="$*"

nextstep

if [ $step -ge $continous ] && [ $serror = 0 ]; then 

	prefix="$(kolor y "#${step}#") $(date) < KOMENDA: $cmd "

	echo -n $prefix | log; 

	if [[ -p /dev/stdin ]]
		then
			pipe="$(< /dev/stdin)"
			
			echo "$pipe" | eval "$cmd"
		else
			eval "$cmd"
	fi

	if [ $? -eq 0 ]; then echo "$(status 0 OK)" | log; serror=0; else echo "$(status 1 ERROR)" | log; serror=1; fi

else

echo "skipping step $step" | log

fi

} 

### PROGRAM ###
###############

. $1
