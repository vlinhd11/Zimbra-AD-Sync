#!/bin/bash

# zcs-sync-ad.sh syncs AD users and Zimbra users
#
# by RaveMaker - http://ravemaker.net

# Load settings
if [ -f settings.cfg ] ; then
    echo "Loading settings..."
    source settings.cfg
else
    echo "ERROR: Create settings.cfg (from settings.cfg.example)"
    exit
fi;

# Folder settings
ADS_TMP=$TMP_DIR/users_ads.lst
ZCS_TMP=$TMP_DIR/users_zcs.lst
DIF_TMP=$TMP_DIR/users_dif.lst

# Clean up users list
rm -f $ADS_TMP $ZCS_TMP $DIF_TMP

# Add excluded accounts to AD list
cat $HOME_DIR/$EXCLUDE_FILE | grep $DOMAIN_NAME > $ADS_TMP

# Extract users from ADS
echo -n "Quering ADS... "
$LDAPSEARCH -x -H $LDAP_SERVER -b $BASEDN -D "$BINDDN" -w $BINDPW "$FILTER" $FIELDS | grep "@$DOMAIN_NAME" | awk '{print $2}' >> $ADS_TMP
sort -k3 $ADS_TMP -o $ADS_TMP
COUNT="$(cat $ADS_TMP | wc -l)"
if [ $COUNT == "0" ]; then exit; fi
echo "Found $COUNT users ($ADS_TMP)"

# Extract users from ZCS
echo -n "Quering ZCS... "
$ZMPROV -l gaa $DOMAIN_NAME > $ZCS_TMP
sort -k3 $ZCS_TMP -o $ZCS_TMP
COUNT="$(cat $ZCS_TMP | wc -l)"
if [ $COUNT == "0" ]; then exit; fi
echo "Found $COUNT users ($ZCS_TMP)"

# Generate diff
echo "Generating diff file ($DIF_TMP)"
diff -u $ZCS_TMP $ADS_TMP | grep "$DOMAIN_NAME" > $DIF_TMP

# Import new users
echo -n "New users: "
cat $DIF_TMP | grep ^+ | wc -l
for i in $(cat $DIF_TMP | grep ^+ | sed s/^+//g);
do
  echo -n " - Adding $i ";
  $ZMPROV createAccount $i passwd > /dev/null;
  RES=$?
  if [ "$RES" == "0" ]; then echo "[Ok]"; else echo "[Err]"; fi
done

# Delete old users
echo -n "Old users: "
cat $DIF_TMP | grep ^- | wc -l
for i in $(cat $DIF_TMP | grep ^- | sed s/^-//g);
do
    read -p "Delete account: $i [y/N]?"
    if [ "$REPLY" == "y" ] || [ "$REPLY" == "Y" ]; then
        echo -n "Deleting account $i..."
        $ZMPROV deleteAccount $i > /dev/null;
        RES=$?
        if [ "$RES" == "0" ]; then echo "[Ok]"; else echo "[Err]"; fi
    fi
done

# Clean up users list
read -p "Keep user lists [y/N]?"
if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
    rm -f $ADS_TMP $ZCS_TMP $DIF_TMP;
fi
echo ""
echo "Done"