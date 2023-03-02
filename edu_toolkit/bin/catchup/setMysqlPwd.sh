if $(mysqladmin -u root password '') ; then
    echo "MySQL password for root was alread set to empty value."
else
    echo "MySQL root password was not blank. Trying again."
fi



