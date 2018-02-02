#!/bin/bash
location=$HOME
file_name="sentinel"
if [ -e $location ] ; then
  echo "OK on the $location directory."
  echo "Now checking on the file, $file_name."
  echo "$location/$file_name"
  if [ -e $location/$file_name ]; then 
    echo "OK on the filename."
    echo "Updating Current Date..."
    date >> $location/$file_name
  else
    echo "File does not exist"
    echo "Nothing to update"
  fi
else 
  echo "The $location directory does not exist."
  echo "Nothing to update"
fi
