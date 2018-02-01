#!/bin/bash
testuser=test1
if grep $testuser /etc/passwd; then 
  echo "The user $testuser exists on this system."
elif ls -d /home/$testuser/ ; then
  echo "However, $testuser has a dirtectory."
fi
