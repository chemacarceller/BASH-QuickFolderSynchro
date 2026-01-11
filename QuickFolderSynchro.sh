#! /bin/bash
# This script is used to update one hard drive folder on another.
# You must pass it the location of the Source and Destination disks folders.
# To do the task, the script performs the following steps:
# 0) Create the destination directory if it doesn't exist.
# 1) For each directory, check for files of type other than directory. If they have content different from the destination, copy them.
# It estimates the different content based on sizes and modification dates.
# 2) Check the list of regular files and directories different from the Destination that are not in the Source and delete them.
# 3) For each Source directory, recursively run the script.

# Wrong arguments
if test $# -ne 2; then
   echo "Wrong arguments";
   exit 1
fi

recursion=false
# Checking Recursion
if [ -z ${MY_COOL_SCRIPT_REC+x} ]; then
   echo -e "Confirm that $2 is correct? Answer Yes to continue, No to cancel \c"; read resp;
   while test "$resp" != "Yes"; do 
      if test "$resp" = "No"; then
         exit 2;
      fi
      echo -e "Confirm that $2 is correct? Answer Yes to continue, No to cancel \c"; read resp;      
   done
else
   recursion=true
fi

# set an env variable local to this shell
export MY_COOL_SCRIPT_REC=1

directorioOrigen="$1"
directorioDestino="$2"

#echo " SOURCE Directory : $1"
#echo " DESTINATION Directory : $2"

IFS='
'
archivosEncontrados=0;
archivosExistentesCopiados=0;
archivosNoExistentesCopiados=0;
archivosDestinoEncontrados=0;
archivosDestinoEliminados=0;

if [ ! -d "$1" ]; then
	# The source directory $1 does not exist.
	echo "The source directory $1 does not exist"
	exit 1
fi

if [ ! -d "$2" ]; then
	# The destination directory $2 does not exist.
	if ! $recursion; then
		echo "The destination directory $2 does not exist."
		exit 1
	else
		echo "The destination directory $2 does not exist, it is created"
		if ! mkdir "$2"; then
			echo "The destination directory $2 could not be created"
			exit 1
		fi
	fi
fi

#echo "SEARCHING FOR FILES IN $1"
# The source files are being searched for
for i in `echo "$1/*"`; do

	# If there are no files, the loop exits.
	if [ "$i" = "$1/*" ]; then
		#echo "There are no files in $1"
		break;
	fi 
	
	# For each SOURCE file, the name, size, and modification date are extracted.
	rutaOrigen="$i";
	nombreOrigen=${rutaOrigen##*/}
	tamanyoOrigen=`ls -l "$i" | cut -f5 -d" "`;
	fechaOrigen=`stat -c %Y "$i"`;
	
	# Files with square brackets cause problems, so they are replaced with hyphens.
	nombreOrigenModificado=`echo $nombreOrigen | tr '[' '-' | tr ']' '-'`;
	if [ "$nombreOrigen" != "$nombreOrigenModificado" ] ; then
		echo "$1 -->  Renamed File $nombreOrigenModificado"
		if ! mv "$1/$nombreOrigen" "$1/$nombreOrigenModificado"; then
			echo "ERROR: Could not rename $1/$nombreOrigen"
		fi
	fi
	
	# From here on you don't need to use $i but $1/$nombreOrigenModificado
	
	# If the file is not a directory
	if [ ! -d "$1/$nombreOrigenModificado" ]; then
		archivosEncontrados=$(( archivosEncontrados + 1  ));

		if [ -f "$2/$nombreOrigenModificado" ]; then
		
			tamanyoDestino=`ls -l "$2/$nombreOrigenModificado" | cut -f5 -d" "`;
			fechaDestino=`stat -c %Y "$2/$nombreOrigenModificado"`;
			
			# If the destination file exists, it is checked whether it has the same content.
	   		#if ! cmp "$i" "$2/$nombreOrigen" >/dev/null 2>/dev/null ; then
	   		# It is verified that they have the same size and the origin date is earlier than the destination date - it is faster than cmp
	   		if [ "$tamanyoOrigen" != "$tamanyoDestino" -o $fechaOrigen -gt $fechaDestino ]; then
	   			# If the files do not have the same content, the file is copied.
	   			archivosExistentesCopiados=$(( archivosExistentesCopiados + 1  )); 
	   			if [ "$tamanyoOrigen" != "$tamanyoDestino" ]; then
					echo "$1 --> $2/$nombreOrigenModificado DIFFERENT SIZES AVAILABLE, COPY AVAILABLE";
				else
					echo "$1 --> $2/$nombreOrigenModificado THERE IS A LATER MODIFICATION DATE IN SOURCE FILE, IT IS COPIED";
				fi
				if ! cp "$1/$nombreOrigenModificado" "$2/$nombreOrigenModificado"; then
					echo "ERROR: Could not be copied $1/$nombreOrigenModificado in $2"
				fi
			#else
				#echo "$1 --> $2/$nombreOrigenModificado THE SAME CONTENT EXISTS, NOTHING IS DONE";
			fi
		else
			# If it does not exist at the destination, it is copied.
			archivosNoExistentesCopiados=$(( archivosNoExistentesCopiados + 1  ));
			echo "$1 --> $2/$nombreOrigenModificado IT DOESN'T EXIST, IT'S COPIED"
			if ! cp "$1/$nombreOrigenModificado" "$2/$nombreOrigenModificado"; then
				echo "ERROR: Could not be copied $1/$nombreOrigenModificado in $2"
			fi
		fi
	fi
done

#echo  -e "\nSTATISTICS $1 :"
#echo "$1 -> Found Files : $archivosEncontrados"
#echo "$1 -> Existing Files Copied : $archivosExistentesCopiados"
#echo -e "$1 -> Non-Existent Files Copied : $archivosNoExistentesCopiados \n\n"

# The destination is traversed to remove files that do not exist in the source.
#echo "SEARCHING FOR FILES IN $2"
for j in `echo "$2/*"`; do

	# If there are no files, the loop exits.
	if [ "$j" = "$2/*" ]; then
		#echo "There are no files in $2"
		break;
	fi
	archivosDestinoEncontrados=$(( archivosDestinoEncontrados + 1  ));
	
	# For each destination file, getting the name
	rutaDestino="$j";
	nombreDestino=${rutaDestino##*/}
	archivoDestinoExisteEnOrigen=false;
	
	# We check if it exists in the Source
	$(ls -l "$1/$nombreDestino" > /dev/null 2>/dev/null);
	if [ $? -eq 0 ]; then
		# The file exists in Source
		archivoDestinoExisteEnOrigen=true
		#if [ -d "$j" ]; then
			#echo "$1 --> DIRECTORY FOUND: $j EXISTS IN SOURCE, NOTHING IS DONE"
		#else
			#echo "$1 --> FILE FOUND: $j EXISTS IN SOURCE, NO ACTION IS REQUIRED"
		#fi
	fi

	# If the file does not exist in the Destination, it is deleted, regardless of whether it is a directory or a file.
	if [ $archivoDestinoExisteEnOrigen = "false" ]; then
		archivosDestinoEliminados=$(( archivosDestinoEliminados + 1  ));
		if [ -d "$j" ]; then
			echo "$1 --> DIRECTORY FOUND: $j DOES NOT EXIST IN SOURCE, IT IS DELETED"
		else
			echo "$1 --> FILE FOUND: $j DOES NOT EXIST IN SOURCE, IT IS DELETED"
		fi
		if ! rm -fr $j; then
			echo "ERROR: Could not be deleted $j from $2"
		fi
	fi
done

#echo -e "\nSTATISTICS $2 :\n"
#echo "$1 -> Destination Files Found : $archivosDestinoEncontrados"
#echo -e "$1 -> Destination Files Deleted : $archivosDestinoEliminados\n\n"

# We trace the origin in search of directories
# The directory exists in Destination, already verified
for i in `echo "$1/*"`; do
	# For each file, getting the name and size
	rutaOrigen="$i";
	nombreOrigen=${rutaOrigen##*/}
	if [ -d "$i" ]; then
		#echo "$1 -->  DIRECTORY FOUND : $i"
		# The script is launched for each of the files
		#echo "$1 --> The script $0 was launched for directory $i and destination $2/$nombreOrigen";
		if ! $0 "$i" "$2/$nombreOrigen"; then
			echo "ERROR: Could not be launched bash $0 $i $2/$nombreOrigen"
		fi
	fi 
done