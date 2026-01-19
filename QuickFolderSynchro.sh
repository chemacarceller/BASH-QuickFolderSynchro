#! /bin/bash
# This script is used to update one hard drive folder onto another.
# You must pass it the location of the Source and Destination disks folders.
# To do the task, the script performs the following steps:
# 0) Create the destination directory if it doesn't exist.
# 1) For each directory, check for files of type other than directory. If they have content different from the destination, copy them.
# It Estimates the different content based on sizes and modification dates of the files.
# 2) Check the list of regular files and directories different from the Destination that are not in the Source and delete them.
# 3) For each Source directory, recursively run this script one by one, it doesnt overload the system with parallel processes

# Wrong arguments
if test $# -ne 2; then
   echo "Wrong arguments" | tee -a QuickFolderSynchro.log
   exit 1
fi

brecursion=false
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
   brecursion=true
fi

# set an env variable local to this shell
export MY_COOL_SCRIPT_REC=1

# Arguments saved in variables but not used
sourceDirectory="$1"
targetDirectory="$2"

#echo " SOURCE Directory : $1" | tee -a QuickFolderSynchro.log
#echo " DESTINATION Directory : $2" | tee -a QuickFolderSynchro.log

IFS='
'

# Files for folder task statistics
foundFilesAndDir=0;
foundFiles=0;
copiedFoundFiles=0;
notCopiedFoundFiles=0;
copiedNotFoundFiles=0;

targetFoundFilesAndDir=0;
targetFoundFiles=0;
targetFoundFilesNotInSource=0;
targetFoundDirNotInSource=0;
targetDeletedFilesAndDir=0;

# The source directory $1 does not exist.
if [ ! -d "$1" ]; then
	echo "The source directory $1 does not exist" | tee -a QuickFolderSynchro.log
	exit 1
fi

	# The destination directory $2 does not exist.
if [ ! -d "$2" ]; then
	if ! $brecursion; then
		# if this is not a child process it must exit
		echo "The destination directory $2 does not exist." | tee -a QuickFolderSynchro.log
		exit 1
	else
		# if this is a child process and the target directory doesnt exist it must be created
		echo "The destination directory $2 does not exist, it is created" | tee -a QuickFolderSynchro.log
		if ! mkdir "$2"; then
			echo "The destination directory $2 could not be created" | tee -a QuickFolderSynchro.log
			exit 1
		fi
	fi
fi

echo "SEARCHING FOR FILES IN $1 : " >> QuickFolderSynchro.log
# The source files are being searched for
for i in `echo "$1/*"`; do

	foundFilesAndDir=$(( foundFilesAndDir + 1  ));

	# If there are no files, the loop exits.
	if [ "$i" = "$1/*" ]; then
		#echo "There are no files in $1"
		break;
	fi 
	
	# For each SOURCE file, the name, size, and modification date are extracted.
	sourcePath="$i";
	sourceName=${sourcePath##*/}
	sourceFileSize=`ls -l "$i" | cut -f5 -d" "`;
	sourceFileModifDate=`stat -c %Y "$i"`;
	
	# Files with square brackets cause problems, so they are replaced with hyphens.
	sourceNameModificado=`echo $sourceName | tr '[' '-' | tr ']' '-'`;
	if [ "$sourceName" != "$sourceNameModificado" ] ; then
		echo "$1 -->  Renamed File $sourceNameModificado" | tee -a QuickFolderSynchro.log
		if ! mv "$1/$sourceName" "$1/$sourceNameModificado"; then
			echo "ERROR: Could not rename $1/$sourceName" | tee -a QuickFolderSynchro.log
		fi
	fi
	
	# From here on you don't need to use $i but $1/$sourceNameModificado
	
	# If the file is not a directory
	if [ ! -d "$1/$sourceNameModificado" ]; then
		foundFiles=$(( foundFiles + 1  ));
		# If the file exist in target directory
		if [ -f "$2/$sourceNameModificado" ]; then

			targetFoundFiles=$(( targetFoundFiles + 1  ));
		
			targetFileSize=`ls -l "$2/$sourceNameModificado" | cut -f5 -d" "`;
			targetFileModifDate=`stat -c %Y "$2/$sourceNameModificado"`;
			
			# If the destination file exists, it is checked whether it has the same content.
	   		#if ! cmp "$i" "$2/$sourceName" >/dev/null 2>/dev/null ; then
	   		# It is verified that they have the same size and the origin date is earlier than the destination date - it is faster than cmp
	   		if [ "$sourceFileSize" != "$targetFileSize" -o $sourceFileModifDate -gt $targetFileModifDate ]; then
	   			# If the files do not have the same content, the file is copied.
	   			copiedFoundFiles=$(( copiedFoundFiles + 1  )); 
	   			if [ "$sourceFileSize" != "$targetFileSize" ]; then
					echo "$2/$sourceNameModificado The source file has a different size than this one, the source file is copied" | tee -a QuickFolderSynchro.log
				else
					echo "$2/$sourceNameModificado The source file has a later modification date than this one, the source file is copied" | tee -a QuickFolderSynchro.log
				fi
				if ! cp "$1/$sourceNameModificado" "$2/$sourceNameModificado"; then
					echo "ERROR: Could not be copied $1/$sourceNameModificado in $2" | tee -a QuickFolderSynchro.log
					copiedFoundFiles=$(( copiedFoundFiles - 1  )); 
				fi
			else
				#echo "$1 --> $2/$sourceNameModificado THE SAME CONTENT EXISTS, NOTHING IS DONE"; | tee -a QuickFolderSynchro.log
				notCopiedFoundFiles=$(( notCopiedFoundFiles + 1  )); 
			fi
		else
			# If it does not exist at the destination, it is copied.
			copiedNotFoundFiles=$(( copiedNotFoundFiles + 1  ));
			echo "$2/$sourceNameModificado doesn't exist, the source file is copied" | tee -a QuickFolderSynchro.log
			if ! cp "$1/$sourceNameModificado" "$2/$sourceNameModificado"; then
				echo "ERROR: Could not be copied $1/$sourceNameModificado in $2" | tee -a QuickFolderSynchro.log
				copiedNotFoundFiles=$(( copiedNotFoundFiles - 1  ));
			fi
		fi
	fi
done

echo  -e "\nSTATISTICS $1 :" >> QuickFolderSynchro.log
echo "$1 -> Found Files Or Directories : $foundFilesAndDir" >> QuickFolderSynchro.log
echo "$1 -> Found Files : $foundFiles" >> QuickFolderSynchro.log
echo "$1 -> Existing Files Copied : $copiedFoundFiles" >> QuickFolderSynchro.log
echo "$1 -> Existing Files Not Copied : $notCopiedFoundFiles" >> QuickFolderSynchro.log
echo -e "$1 -> Non-Existent Files Copied : $copiedNotFoundFiles \n\n" >> QuickFolderSynchro.log

# The destination is traversed to remove files that do not exist in the source.
echo "SEARCHING FOR FILES IN $2" >> QuickFolderSynchro.log
for j in `echo "$2/*"`; do

	# If there are no files, the loop exits.
	if [ "$j" = "$2/*" ]; then
		#echo "There are no files in $2" | tee -a QuickFolderSynchro.log
		break;
	fi

	targetFoundFilesAndDir=$(( targetFoundFilesAndDir + 1  ));
	
	# For each destination file, getting the name
	targetPath="$j";
	targetFileName=${targetPath##*/}
	btargetFileExistInSource=false;
	
	# We check if it exists in the Source
	$(ls -l "$1/$targetFileName" > /dev/null 2>/dev/null);
	if [ $? -eq 0 ]; then
		# The file exists in Source
		btargetFileExistInSource=true
		#if [ -d "$j" ]; then
			#echo "DIRECTORY FOUND: $j EXISTS IN SOURCE, NOTHING IS DONE" | tee -a QuickFolderSynchro.log
		#else
			#echo "FILE FOUND: $j EXISTS IN SOURCE, NO ACTION IS REQUIRED" | tee -a QuickFolderSynchro.log
		#fi
	fi

	# If the file does not exist in the Destination, it is deleted, regardless of whether it is a directory or a file.
	if [ $btargetFileExistInSource = "false" ]; then
		targetDeletedFilesAndDir=$(( targetDeletedFilesAndDir + 1  ));
		if [ -d "$j" ]; then
			echo "DIRECTORY FOUND: $j DOES NOT EXIST IN SOURCE, IT IS DELETED" | tee -a QuickFolderSynchro.log
			targetFoundDirNotInSource=$(( targetFoundDirNotInSource + 1  ));
		else
			echo "FILE FOUND: $j DOES NOT EXIST IN SOURCE, IT IS DELETED" | tee -a QuickFolderSynchro.log
			targetFoundFilesNotInSource=$(( targetFoundFilesNotInSource + 1  ));
			
		fi
		if ! rm -fr $j; then
			echo "ERROR: Could not be deleted $j from $2" | tee -a QuickFolderSynchro.log
			targetDeletedFilesAndDir=$(( targetDeletedFilesAndDir - 1  ));
		fi
	fi
done

echo -e "\nSTATISTICS $2 :\n" >> QuickFolderSynchro.log
echo "$1 -> Destination Files or Directories Found : $targetFoundFilesAndDir" >> QuickFolderSynchro.log
echo "$1 -> Destination Files Found that exist in Source : $targetFoundFiles" >> QuickFolderSynchro.log
echo "$1 -> Destination Files Found that not exist in Source : $targetFoundFilesNotInSource" >> QuickFolderSynchro.log
echo -e "$1 -> Destination Files or Directories Deleted : $targetDeletedFilesAndDir\n\n" >> QuickFolderSynchro.log

# We trace the origin in search of directories
# The directory exists in Destination, already verified
for i in `echo "$1/*"`; do
	# For each file, getting the name and size
	sourcePath="$i";
	sourceName=${sourcePath##*/}
	if [ -d "$i" ]; then
		#echo "$1 -->  DIRECTORY FOUND : $i" | tee -a QuickFolderSynchro.log
		# The script is launched for each of the files
		#echo "$1 --> The script $0 was launched for directory $i and destination $2/$sourceName" | tee -a QuickFolderSynchro.log
		if ! $0 "$i" "$2/$sourceName"; then
			echo "ERROR: Could not be launched bash $0 $i $2/$sourceName" | tee -a QuickFolderSynchro.log
		fi
	fi 
done