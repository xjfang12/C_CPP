#!/bin/bash
pwfile=/etc/shadow
if [ -f $pwfile ] ; then
  if [ -r $pwfile ]; then
	tail $pwfile
  else
	echo "Sorry, I am unable to read the $pwfile file"
  fi
else
  echo "sorry, the file $file does not exist"
fi
